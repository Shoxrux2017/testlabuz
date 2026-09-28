import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_homework_attempt_repository_impl.dart';
import '../domain/student_answer_draft.dart';
import '../domain/student_answer_mutation.dart';
import '../domain/student_homework.dart';
import '../domain/student_homework_attempt.dart';
import '../domain/student_homework_attempt_route_target.dart';
import '../domain/student_homework_route_target.dart';
import '../domain/student_question.dart';
import 'student_answer_autosave.dart';
import 'student_attempt_answer_editor_state.dart';
import 'student_attempt_route_operation_gate.dart';
import 'student_homework_attempt_controller.dart';
import 'student_homework_attempt_state.dart';
import 'student_homework_detail_controller.dart';
import 'student_session_key.dart';

final studentAttemptAnswerEditorControllerProvider = NotifierProvider
    .autoDispose
    .family<
      StudentAttemptAnswerEditorController,
      StudentAttemptAnswerEditorState,
      StudentHomeworkAttemptRouteTarget
    >(StudentAttemptAnswerEditorController.new);

class StudentAttemptAnswerEditorController
    extends Notifier<StudentAttemptAnswerEditorState> {
  StudentAttemptAnswerEditorController(this.target);

  final StudentHomeworkAttemptRouteTarget target;
  StudentSessionKey? _activeSessionKey;
  StudentHomeworkAttemptState? _lastParent;
  StudentAnswerAutosave? _autosave;
  Completer<bool>? _flush;
  var _generation = 0;
  var _cleared = false;

  @override
  StudentAttemptAnswerEditorState build() {
    final buildRef = ref;
    // A rebuild keeps its Ref mounted while these callbacks run; only a real
    // disposal stops the autosave timers.
    buildRef.onDispose(() {
      if (!buildRef.mounted) _stopAutosave();
    });
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final parent = ref.watch(studentHomeworkAttemptControllerProvider(target));
    if (key == null) {
      _invalidateOwnership();
      return StudentAttemptAnswerEditorState();
    }
    final resetScope = _activeSessionKey != key || ref.isRefresh;
    if (resetScope) {
      _invalidateOwnership();
      _activeSessionKey = key;
      _cleared = false;
    }
    if (_cleared) return StudentAttemptAnswerEditorState();
    final previous = resetScope ? StudentAttemptAnswerEditorState() : state;
    final changedParent = !identical(parent, _lastParent);
    _lastParent = parent;
    final StudentAttemptAnswerEditorState next;
    if (changedParent &&
        parent.status == StudentHomeworkAttemptLoadStatus.data &&
        parent.attempt != null &&
        _matchesAttempt(parent.attempt!)) {
      next = _synchronize(
        previous,
        parent.attempt!,
        sourcePublication: parent.publicationToken,
      );
    } else {
      next = _copyState(previous, isAuthoritative: _hasSaveAuthority(parent));
    }
    // Saves that waited for authority, and a waiting flush, continue after
    // this build publishes.
    if (_autosave != null || _flush != null) {
      scheduleMicrotask(() {
        if (!ref.mounted) return;
        _pump();
        _evaluateFlush();
      });
    }
    return next;
  }

  void updateDraft(String questionId, StudentAnswerDraft draft) {
    final id = questionId.toLowerCase();
    if (!_canEdit(id)) return;
    final entry = state.questions[id]!;
    final keepsStatus =
        entry.saveStatus == StudentAnswerSaveStatus.saving ||
        entry.saveStatus == StudentAnswerSaveStatus.uncertain;
    final next = StudentQuestionAnswerEditorState(
      question: entry.question,
      serverAnswer: entry.serverAnswer,
      updatedAt: entry.updatedAt,
      draft: draft,
      saveStatus: keepsStatus ? entry.saveStatus : StudentAnswerSaveStatus.idle,
      failure: keepsStatus ? entry.failure : null,
    );
    _replaceQuestion(id, next);
    if (next.isDirty) {
      _queue.changed(id);
    } else {
      _queue.forget(id);
    }
  }

  void clearAnswer(String questionId) {
    final id = questionId.toLowerCase();
    if (!_canEdit(id)) return;
    final entry = state.questions[id]!;
    if (entry.draft.canClear) {
      updateDraft(id, entry.draft.clear(entry.question));
    }
  }

  /// Sends one changed Question without waiting, for example when its text
  /// field loses focus.
  void saveNow(String questionId) {
    final id = questionId.toLowerCase();
    if (!_canEdit(id) || !state.questions[id]!.isDirty) return;
    _queue.dueNow(id);
  }

  /// Sends every changed Question without waiting, for example when the app
  /// goes to the background.
  void saveAllNow() => _queueEveryDirtyQuestion();

  /// Sends every pending change and completes with `true` once all answers are
  /// saved, or `false` as soon as one cannot be saved or [cancelFlush] runs.
  Future<bool> flushAll() {
    final existing = _flush;
    if (existing != null) return existing.future;
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        !state.isEligible ||
        state.terminalAttempt != null) {
      return Future.value(false);
    }
    final completer = Completer<bool>();
    _flush = completer;
    state = _copyState(state);
    _queueEveryDirtyQuestion();
    _evaluateFlush();
    return completer.future;
  }

  void _queueEveryDirtyQuestion() {
    for (final entry in state.questions.entries) {
      if (entry.value.isDirty && entry.value.validation == null) {
        _queue.dueNow(entry.key);
      }
    }
  }

  void cancelFlush() => _endFlush(false);

  void clearLocalState() {
    final clearedSession = _activeSessionKey;
    _invalidateOwnership();
    _activeSessionKey = clearedSession;
    _cleared = true;
    state = StudentAttemptAnswerEditorState();
  }

  Future<void> saveAnswer(String questionId) async {
    final id = questionId.toLowerCase();
    final key = _activeSessionKey;
    final parent = ref.read(studentHomeworkAttemptControllerProvider(target));
    if (!_gateIsIdle ||
        key == null ||
        !_matchesSession(key) ||
        !_hasSaveAuthority(parent) ||
        !state.canSave(id)) {
      return;
    }

    final entry = state.questions[id]!;
    final snapshot = entry.draft.toMutation(entry.question);
    final mutationPublication = state.sourceAttemptPublication;
    final readToken = parent.readToken;
    final generation = ++_generation;
    final requestTarget = target;
    _queue.sending(id);
    state = _copyState(
      state,
      questions: {
        ...state.questions,
        id: _withStatus(entry, StudentAnswerSaveStatus.saving),
      },
      activeQuestionId: id,
      pendingMutationSnapshot: snapshot,
    );
    try {
      final result = await ref
          .read(studentHomeworkAttemptRepositoryProvider)
          .saveAnswer(requestTarget.attemptId, entry.question, snapshot);
      if (!_canPublish(generation, key, requestTarget, id, snapshot)) return;
      final current = state.questions[id]!;
      final parentAttempt = ref
          .read(studentHomeworkAttemptControllerProvider(target))
          .attempt;
      if (parentAttempt != null &&
          (!parentAttempt.questions.any(
                (question) => question.id.toLowerCase() == id,
              ) ||
              !_matchesAttempt(parentAttempt))) {
        throw _invalidResponse();
      }
      if (!_validResult(result, current.question)) throw _invalidResponse();
      final dirty = current.draft.isDirty(current.question, result.answer);
      // The local draft is never replaced: it may already hold newer typing.
      _finishQuestion(
        id,
        StudentQuestionAnswerEditorState(
          question: current.question,
          serverAnswer: result.answer,
          updatedAt: result.updatedAt,
          draft: current.draft,
          saveStatus: dirty
              ? StudentAnswerSaveStatus.idle
              : StudentAnswerSaveStatus.saved,
        ),
        preservePublication: identical(
          mutationPublication,
          state.sourceAttemptPublication,
        ),
      );
      _queue.finished(id, dirty: dirty);
      final patched = ref
          .read(studentHomeworkAttemptControllerProvider(target).notifier)
          .acceptAnswerMutation(
            questionId: id,
            result: result,
            expectedReadToken: readToken,
          );
      if (!patched) {
        ref
            .read(studentHomeworkAttemptControllerProvider(target).notifier)
            .refreshAfterWrite();
      }
      _pump();
      _evaluateFlush();
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key, requestTarget, id, snapshot) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      final failure = exception.failure;
      final current = state.questions[id]!;
      if (_isUncertain(failure)) {
        _replaceQuestion(
          id,
          _withStatus(current, StudentAnswerSaveStatus.uncertain, failure),
        );
        _queue.scheduleRecovery(_recover);
      } else if (!identical(current.draft, entry.draft)) {
        // The rejection is for the sent value; typing made meanwhile is a new
        // value and is saved as usual.
        _finishQuestion(id, _withStatus(current, StudentAnswerSaveStatus.idle));
        _queue.finished(id, dirty: current.isDirty);
        _reconcileFailure(failure);
      } else {
        _finishQuestion(
          id,
          _withStatus(current, StudentAnswerSaveStatus.failure, failure),
        );
        _queue.rejected(id);
        _reconcileFailure(failure);
      }
      _evaluateFlush();
    }
  }

  Future<void> reloadAttempt() async {
    final key = _activeSessionKey;
    final id = state.activeQuestionId;
    final snapshot = state.pendingMutationSnapshot;
    if (!_gateIsIdle ||
        key == null ||
        id == null ||
        snapshot == null ||
        !_matchesSession(key) ||
        !state.hasUncertainMutation ||
        state.isReconciling) {
      return;
    }
    final generation = ++_generation;
    final requestTarget = target;
    state = _copyState(state, isReconciling: true);
    try {
      // This owned GET alone can prove the outcome of the uncertain PUT.
      final attempt = await ref
          .read(studentHomeworkAttemptRepositoryProvider)
          .fetchAttempt(requestTarget.attemptId);
      if (!_canPublish(generation, key, requestTarget, id, snapshot)) return;
      if (!_matchesAttempt(attempt)) throw _invalidResponse();
      if (attempt.status != StudentHomeworkAttemptStatus.inProgress) {
        state = _synchronize(state, attempt);
        _refreshAttempt();
        return;
      }
      final matchingQuestions = attempt.questions.where(
        (question) => question.id.toLowerCase() == id,
      );
      if (matchingQuestions.length != 1 ||
          matchingQuestions.single.type != snapshot.type) {
        throw _invalidResponse();
      }
      final question = matchingQuestions.single;
      final answer = _answerFor(attempt, id);
      final refreshed = _synchronize(state, attempt);
      state = _copyState(refreshed, isAuthoritative: false);
      // Typing continued during the uncertain save; keep it and save it again
      // if the server does not already hold it.
      final draft = state.questions[id]!.draft;
      final dirty = draft.isDirty(question, answer?.value);
      _finishQuestion(
        id,
        StudentQuestionAnswerEditorState(
          question: question,
          serverAnswer: answer?.value,
          updatedAt: answer?.updatedAt,
          draft: draft,
          saveStatus: dirty
              ? StudentAnswerSaveStatus.idle
              : StudentAnswerSaveStatus.saved,
        ),
      );
      _queue
        ..resetRecovery()
        ..finished(id, dirty: dirty);
      _refreshAttempt();
      _evaluateFlush();
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key, requestTarget, id, snapshot) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      state = _copyState(
        state,
        questions: {
          ...state.questions,
          id: _withStatus(
            state.questions[id]!,
            StudentAnswerSaveStatus.uncertain,
            exception.failure,
          ),
        },
        isReconciling: false,
      );
      _queue.scheduleRecovery(_recover);
      _evaluateFlush();
    }
  }

  StudentAnswerAutosave get _queue => _autosave ??= StudentAnswerAutosave(
    ref.read(studentAutosaveTimerFactoryProvider),
    _pump,
  );

  void _pump() {
    final autosave = _autosave;
    if (autosave == null ||
        !ref.mounted ||
        state.activeQuestionId != null ||
        state.isReconciling) {
      return;
    }
    final next = autosave.next(state.canSave);
    if (next != null) unawaited(saveAnswer(next));
  }

  void _recover() {
    if (!ref.mounted ||
        !state.hasUncertainMutation ||
        state.terminalAttempt != null) {
      return;
    }
    if (!_gateIsIdle || state.isReconciling) {
      _queue.scheduleRecovery(_recover);
      return;
    }
    unawaited(reloadAttempt());
  }

  void _evaluateFlush() {
    if (_flush == null || !ref.mounted) return;
    final parent = ref.read(studentHomeworkAttemptControllerProvider(target));
    if (!state.isEligible ||
        state.terminalAttempt != null ||
        state.hasUncertainMutation ||
        state.hasInvalidDraft ||
        state.hasFailedSave ||
        parent.status == StudentHomeworkAttemptLoadStatus.error ||
        parent.status == StudentHomeworkAttemptLoadStatus.notFound) {
      _endFlush(false);
      return;
    }
    final settled =
        !state.hasDirtyDrafts &&
        state.activeQuestionId == null &&
        !state.isReconciling &&
        state.questions.values.every(
          (entry) => entry.saveStatus != StudentAnswerSaveStatus.saving,
        );
    if (settled) _endFlush(true);
  }

  void _endFlush(bool saved) {
    final completer = _flush;
    if (completer == null) return;
    _flush = null;
    if (ref.mounted && state.isFlushing) state = _copyState(state);
    completer.complete(saved);
  }

  void _stopAutosave() {
    _autosave?.clear();
    final completer = _flush;
    _flush = null;
    completer?.complete(false);
  }

  StudentAttemptAnswerEditorState _synchronize(
    StudentAttemptAnswerEditorState previous,
    StudentHomeworkAttempt attempt, {
    StudentHomeworkAttemptPublicationToken? sourcePublication,
  }) {
    final terminal = attempt.status != StudentHomeworkAttemptStatus.inProgress;
    if (previous.terminalAttempt != null && !terminal) return previous;
    if (terminal) {
      _generation += 1;
      _stopAutosave();
    }
    var preservedUncertainty = false;
    final questions = <String, StudentQuestionAnswerEditorState>{};
    for (final question in attempt.questions) {
      if (question.type == StudentQuestionType.fileBased) continue;
      final id = question.id.toLowerCase();
      final previousQuestion = previous.questions[id];
      if (!terminal &&
          previousQuestion?.saveStatus == StudentAnswerSaveStatus.uncertain) {
        questions[id] = previousQuestion!;
        preservedUncertainty = true;
        continue;
      }
      final answer = _answerFor(attempt, id);
      // A dirty or saving draft is the Student's newer intent. A clean draft
      // keeps its own object while it still matches the server, so the text
      // field is not rewritten; otherwise it shows the newer server value.
      final keepDraft =
          !terminal &&
          previousQuestion != null &&
          (previousQuestion.isDirty ||
              previousQuestion.saveStatus == StudentAnswerSaveStatus.saving ||
              !previousQuestion.draft.isDirty(question, answer?.value));
      questions[id] = StudentQuestionAnswerEditorState(
        question: question,
        serverAnswer: answer?.value,
        updatedAt: answer?.updatedAt,
        draft: keepDraft
            ? previousQuestion.draft
            : StudentAnswerDraft.fromAnswer(question, answer?.value),
        saveStatus: terminal
            ? StudentAnswerSaveStatus.idle
            : previousQuestion?.saveStatus ?? StudentAnswerSaveStatus.idle,
        failure: terminal ? null : previousQuestion?.failure,
      );
    }
    final activeId = previous.activeQuestionId;
    if (!terminal && activeId != null && !questions.containsKey(activeId)) {
      final activeQuestion = previous.questions[activeId];
      if (activeQuestion != null) {
        // An ordinary refresh cannot remove the uncertain operation's recovery.
        questions[activeId] = activeQuestion;
        preservedUncertainty = true;
      }
    }
    return StudentAttemptAnswerEditorState(
      questions: questions,
      isEligible: true,
      isAuthoritative: !terminal,
      activeQuestionId: terminal ? null : previous.activeQuestionId,
      pendingMutationSnapshot: terminal
          ? null
          : previous.pendingMutationSnapshot,
      isReconciling: !terminal && previous.isReconciling,
      terminalAttempt: terminal ? attempt : null,
      sourceAttemptPublication: preservedUncertainty ? null : sourcePublication,
      isFlushing: _flush != null,
    );
  }

  StudentAttemptAnswerState? _answerFor(
    StudentHomeworkAttempt attempt,
    String id,
  ) {
    for (final answer in attempt.answers) {
      if (answer.questionId.toLowerCase() == id) return answer;
    }
    return null;
  }

  bool _hasSaveAuthority(StudentHomeworkAttemptState parent) =>
      !_cleared &&
      parent.status == StudentHomeworkAttemptLoadStatus.data &&
      parent.attempt != null &&
      _matchesAttempt(parent.attempt!) &&
      parent.attempt!.status == StudentHomeworkAttemptStatus.inProgress;

  bool _matchesAttempt(StudentHomeworkAttempt attempt) =>
      isCanonicalStudentAttemptId(attempt.id) &&
      isCanonicalStudentAttemptId(target.attemptId) &&
      isCanonicalStudentHomeworkId(attempt.assessmentId) &&
      isCanonicalStudentHomeworkId(target.homeworkId) &&
      attempt.id.toLowerCase() == target.attemptId.toLowerCase() &&
      attempt.assessmentId.toLowerCase() == target.homeworkId.toLowerCase();

  bool _canEdit(String id) {
    final key = _activeSessionKey;
    return _gateIsIdle &&
        key != null &&
        _matchesSession(key) &&
        state.canEdit(id);
  }

  bool get _gateIsIdle =>
      ref.read(studentAttemptRouteOperationGateProvider(target)) ==
      StudentAttemptRouteOperation.idle;

  bool _canPublish(
    int generation,
    StudentSessionKey key,
    StudentHomeworkAttemptRouteTarget requestTarget,
    String id,
    StudentAnswerMutation snapshot,
  ) =>
      ref.mounted &&
      _matchesSession(key) &&
      generation == _generation &&
      target == requestTarget &&
      state.terminalAttempt == null &&
      state.activeQuestionId == id &&
      state.questions.containsKey(id) &&
      identical(state.pendingMutationSnapshot, snapshot);

  bool _matchesSession(StudentSessionKey key) =>
      ref.mounted &&
      !_cleared &&
      _activeSessionKey == key &&
      StudentSessionSnapshot.fromSession(
            ref.read(authSessionControllerProvider),
            ref.read(appDeviceSurfaceProvider),
          ).eligibleKey ==
          key;

  bool _validResult(
    StudentAttemptAnswerMutationResult result,
    StudentQuestion question,
  ) {
    if (!isCanonicalStudentAttemptId(result.questionId) ||
        result.questionId.toLowerCase() != question.id.toLowerCase() ||
        result.type != question.type ||
        (result.answer == null) != (result.updatedAt == null)) {
      return false;
    }
    final answer = result.answer;
    if (answer == null) {
      return StudentAnswerDraft.fromAnswer(question, null).canClear;
    }
    if (answer is StudentChoiceAnswerValue &&
        (answer.selectedOptionIds.isEmpty ||
            (question.type == StudentQuestionType.singleChoice &&
                answer.selectedOptionIds.length != 1))) {
      return false;
    }
    final correctShape = switch (question.type) {
      StudentQuestionType.singleChoice ||
      StudentQuestionType.multipleChoice => answer is StudentChoiceAnswerValue,
      StudentQuestionType.trueFalse => answer is StudentBooleanAnswerValue,
      StudentQuestionType.shortWritten ||
      StudentQuestionType.openWritten => answer is StudentTextAnswerValue,
      StudentQuestionType.matching => answer is StudentMatchingAnswerValue,
      StudentQuestionType.ordering => answer is StudentOrderingAnswerValue,
      StudentQuestionType.fillInBlank => answer is StudentFillBlankAnswerValue,
      StudentQuestionType.fileBased => false,
    };
    return correctShape &&
        StudentAnswerDraft.fromAnswer(question, answer).validate(question) ==
            null;
  }

  ApiRequestException _invalidResponse() => ApiRequestException(
    ApiFailure.local(
      kind: ApiFailureKind.invalidResponse,
      message: 'The answer response could not be confirmed.',
    ),
  );

  bool _isUncertain(ApiFailure failure) => switch (failure.kind) {
    ApiFailureKind.connection ||
    ApiFailureKind.timeout ||
    ApiFailureKind.cancelled ||
    ApiFailureKind.invalidResponse ||
    ApiFailureKind.unknown => true,
    ApiFailureKind.server || ApiFailureKind.validation =>
      failure.statusCode == null || failure.statusCode! >= 500,
  };

  void _reconcileFailure(ApiFailure failure) {
    switch (failure.serverCode) {
      case ApiErrorCodes.selectionLimitExceeded:
      case ApiErrorCodes.attemptNotEditable:
      case ApiErrorCodes.resourceNotFound:
      case ApiErrorCodes.businessConflict:
        _refreshAttempt();
      case ApiErrorCodes.deadlinePassed:
      case ApiErrorCodes.taskClosed:
      case ApiErrorCodes.taskArchived:
      case ApiErrorCodes.taskNotActive:
        _refreshAttempt();
        ref.invalidate(
          studentHomeworkDetailControllerProvider(
            StudentHomeworkRouteTarget(
              topicId: target.topicId,
              homeworkId: target.homeworkId,
            ),
          ),
        );
    }
  }

  void _refreshAttempt() => ref
      .read(studentHomeworkAttemptControllerProvider(target).notifier)
      .refresh();

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }
    clearLocalState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _invalidateOwnership() {
    _generation += 1;
    _activeSessionKey = null;
    _lastParent = null;
    _stopAutosave();
  }

  StudentQuestionAnswerEditorState _withStatus(
    StudentQuestionAnswerEditorState entry,
    StudentAnswerSaveStatus status, [
    ApiFailure? failure,
  ]) => StudentQuestionAnswerEditorState(
    question: entry.question,
    serverAnswer: entry.serverAnswer,
    updatedAt: entry.updatedAt,
    draft: entry.draft,
    saveStatus: status,
    failure: failure,
  );

  void _replaceQuestion(String id, StudentQuestionAnswerEditorState entry) {
    state = _copyState(state, questions: {...state.questions, id: entry});
  }

  void _finishQuestion(
    String id,
    StudentQuestionAnswerEditorState entry, {
    bool preservePublication = true,
  }) {
    state = StudentAttemptAnswerEditorState(
      questions: {...state.questions, id: entry},
      isEligible: state.isEligible,
      isAuthoritative: state.isAuthoritative,
      terminalAttempt: state.terminalAttempt,
      sourceAttemptPublication: preservePublication
          ? state.sourceAttemptPublication
          : null,
      isFlushing: _flush != null,
    );
  }

  StudentAttemptAnswerEditorState _copyState(
    StudentAttemptAnswerEditorState previous, {
    Map<String, StudentQuestionAnswerEditorState>? questions,
    bool? isAuthoritative,
    String? activeQuestionId,
    StudentAnswerMutation? pendingMutationSnapshot,
    bool? isReconciling,
  }) => StudentAttemptAnswerEditorState(
    questions: questions ?? previous.questions,
    isEligible: _activeSessionKey != null && !_cleared,
    isAuthoritative: isAuthoritative ?? previous.isAuthoritative,
    activeQuestionId: activeQuestionId ?? previous.activeQuestionId,
    pendingMutationSnapshot:
        pendingMutationSnapshot ?? previous.pendingMutationSnapshot,
    isReconciling: isReconciling ?? previous.isReconciling,
    terminalAttempt: previous.terminalAttempt,
    sourceAttemptPublication: previous.sourceAttemptPublication,
    isFlushing: _flush != null,
  );
}
