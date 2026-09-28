import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_attempt_answer_repository_impl.dart';
import '../domain/student_answer_draft.dart';
import '../domain/student_answer_mutation.dart';
import '../domain/student_attempt_answer.dart';
import '../domain/student_blitz_attempt.dart';
import '../domain/student_blitz_execution_target.dart';
import '../domain/student_question.dart';
import 'student_answer_autosave.dart';
import 'student_attempt_answer_editor_state.dart';
import 'student_attempt_publication_token.dart';
import 'student_blitz_answer_editor_state.dart';
import 'student_blitz_execution_controller.dart';
import 'student_blitz_execution_operation_gate.dart';
import 'student_blitz_execution_state.dart';
import 'student_session_key.dart';

final studentBlitzAnswerEditorControllerProvider = NotifierProvider.autoDispose
    .family<
      StudentBlitzAnswerEditorController,
      StudentBlitzAnswerEditorState,
      StudentBlitzExecutionTarget
    >(StudentBlitzAnswerEditorController.new);

/// Non-file answer editing for one Blitz execution Attempt. The editor
/// widgets and drafts are the shared Stage 7 ones; only the orchestration is
/// Blitz-specific, because the parent Attempt authority has no read API.
class StudentBlitzAnswerEditorController
    extends Notifier<StudentBlitzAnswerEditorState> {
  StudentBlitzAnswerEditorController(this.target);

  final StudentBlitzExecutionTarget target;
  StudentSessionKey? _activeSessionKey;
  StudentAttemptPublicationToken? _lastPublication;
  StudentAnswerAutosave? _autosave;
  Completer<bool>? _flush;
  var _generation = 0;
  var _cleared = false;

  @override
  StudentBlitzAnswerEditorState build() {
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
    final parent = ref.watch(
      studentBlitzExecutionControllerProvider(target.routeTarget),
    );
    ref.watch(studentBlitzExecutionOperationGateProvider(target));
    if (key == null) {
      _invalidateOwnership();
      return StudentBlitzAnswerEditorState();
    }
    final resetScope = _activeSessionKey != key || ref.isRefresh;
    if (resetScope) {
      _invalidateOwnership();
      _activeSessionKey = key;
      _cleared = false;
    }
    final attempt = parent.attempt;
    if (_cleared || attempt == null || !_matchesAttempt(attempt)) {
      _lastPublication = null;
      _stopAutosave();
      return StudentBlitzAnswerEditorState();
    }
    final previous = resetScope ? StudentBlitzAnswerEditorState() : state;
    // Nothing is sent after local zero, even if a later replay re-opens writes.
    if (parent.localTimeExpired) _stopAutosave();
    final publication = parent.publicationToken;
    final StudentBlitzAnswerEditorState next;
    if (publication != null && !identical(publication, _lastPublication)) {
      _lastPublication = publication;
      next = _synchronize(previous, parent);
    } else {
      next = _copyState(
        previous,
        isAuthoritative: _hasSaveAuthority(parent),
        isRunning: _isRunning(parent),
      );
    }
    // Saves that waited for the write gate, and a waiting flush, continue
    // after this build publishes.
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
  /// goes to the background. Nothing is queued after local zero.
  void saveAllNow() {
    final parent = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget),
    );
    if (!parent.localTimeExpired) _queueEveryDirtyQuestion();
  }

  /// Sends every pending change and completes with `true` once all answers are
  /// saved, or `false` as soon as one cannot be saved, the time is over, or
  /// [cancelFlush] runs.
  Future<bool> flushAll() {
    final existing = _flush;
    if (existing != null) return existing.future;
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        !state.isEligible ||
        !state.isAuthoritative ||
        state.isTerminal) {
      return Future.value(false);
    }
    final completer = Completer<bool>();
    _flush = completer;
    state = _copyState(state);
    _queueEveryDirtyQuestion();
    _evaluateFlush();
    return completer.future;
  }

  void cancelFlush() => _endFlush(false);

  /// Leaving discards only unsaved local drafts; nothing is sent.
  void clearLocalState() {
    final clearedSession = _activeSessionKey;
    _invalidateOwnership();
    _activeSessionKey = clearedSession;
    _cleared = true;
    state = StudentBlitzAnswerEditorState();
  }

  /// Sends one answer PUT. A value the server rejected is never resent on its
  /// own; an unconfirmed one is checked by replaying the Start request.
  Future<void> saveAnswer(String questionId) async {
    final id = questionId.toLowerCase();
    final key = _activeSessionKey;
    final execution = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget).notifier,
    );
    if (!_gateIsIdle ||
        key == null ||
        !_matchesSession(key) ||
        !_hasSaveAuthority(
          ref.read(studentBlitzExecutionControllerProvider(target.routeTarget)),
        ) ||
        !state.canSave(id)) {
      return;
    }
    // A busy write gate (a replay is pending) keeps the Question queued; the
    // next publication sends it.
    final write = execution.beginWrite();
    if (write == null) return;

    final entry = state.questions[id]!;
    final snapshot = entry.draft.toMutation(entry.question);
    final readToken = ref
        .read(studentBlitzExecutionControllerProvider(target.routeTarget))
        .readToken;
    final generation = ++_generation;
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
          .read(studentAttemptAnswerRepositoryProvider)
          .saveAnswer(target.attemptId, entry.question, snapshot);
      if (!_canPublish(generation, key, id, snapshot)) return;
      if (!_validResult(result, state.questions[id]!.question)) {
        throw _invalidResponse();
      }
      final accepted = execution.acceptAnswerMutation(
        attemptId: target.attemptId,
        questionId: id,
        result: result,
        expectedReadToken: readToken,
      );
      if (!accepted) {
        // A replay adopted the Attempt meanwhile; only a check may show the
        // result.
        _replaceQuestion(
          id,
          _withStatus(
            state.questions[id]!,
            StudentAnswerSaveStatus.uncertain,
            _invalidResponse().failure,
          ),
        );
        unawaited(checkCurrentAttempt());
        _evaluateFlush();
        return;
      }
      _adoptSaved(id, result);
      _pump();
      _evaluateFlush();
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key, id, snapshot) ||
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
        _evaluateFlush();
        return;
      }
      if (identical(current.draft, entry.draft)) {
        _finishQuestion(
          id,
          _withStatus(current, StudentAnswerSaveStatus.failure, failure),
        );
        _queue.rejected(id);
      } else {
        // The rejection is for the sent value; typing made meanwhile is a new
        // value and is saved as usual.
        _finishQuestion(id, _withStatus(current, StudentAnswerSaveStatus.idle));
        _queue.finished(id, dirty: current.isDirty);
      }
      _evaluateFlush();
      if (_reconciledCodes.contains(failure.serverCode)) {
        unawaited(execution.reconcileAfterRejectedWrite(failure));
      }
    } catch (_) {
      // The PUT may have committed; only a check can show its outcome.
      if (_canPublish(generation, key, id, snapshot)) {
        _replaceQuestion(
          id,
          _withStatus(
            state.questions[id]!,
            StudentAnswerSaveStatus.uncertain,
            ApiFailure.local(
              kind: ApiFailureKind.unknown,
              message: 'Unexpected answer save failure.',
            ),
          ),
        );
        _queue.scheduleRecovery(_recover);
        _evaluateFlush();
      }
    } finally {
      execution.endWrite(write);
    }
  }

  /// Re-reads the current Attempt by replaying the completed Start request,
  /// then classifies the unconfirmed save against the server answer.
  Future<void> checkCurrentAttempt() async {
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
    state = _copyState(state, isReconciling: true);
    final outcome = await ref
        .read(
          studentBlitzExecutionControllerProvider(target.routeTarget).notifier,
        )
        .refreshCurrentAttempt();
    // A terminal or dropped execution already retired this operation.
    if (!_canPublish(generation, key, id, snapshot)) return;
    final parent = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget),
    );
    final attempt = parent.attempt;
    final questions =
        attempt?.questions.where(
          (question) => question.id.toLowerCase() == id,
        ) ??
        const <StudentQuestion>[];
    if (outcome != StudentBlitzAttemptReplayOutcome.active ||
        attempt == null ||
        attempt.status != StudentBlitzAttemptStatus.inProgress ||
        questions.length != 1 ||
        questions.single.type != snapshot.type) {
      state = _copyState(state, isReconciling: false);
      if (state.hasUncertainMutation && !state.isTerminal) {
        _queue.scheduleRecovery(_recover);
      }
      _evaluateFlush();
      return;
    }
    final question = questions.single;
    final answer = _answerFor(attempt, id);
    // Typing continued during the unconfirmed save; keep it and save it again
    // if the server does not already hold it.
    final draft = state.questions[id]!.draft;
    final dirty = draft.isDirty(question, answer?.value);
    final resolved = StudentBlitzAnswerEditorState(
      questions: {
        ...state.questions,
        id: StudentQuestionAnswerEditorState(
          question: question,
          serverAnswer: answer?.value,
          updatedAt: answer?.updatedAt,
          draft: draft,
          saveStatus: dirty
              ? StudentAnswerSaveStatus.idle
              : StudentAnswerSaveStatus.saved,
        ),
      },
      isEligible: state.isEligible,
    );
    _lastPublication = parent.publicationToken;
    state = _synchronize(resolved, parent);
    _queue
      ..resetRecovery()
      ..finished(id, dirty: dirty);
    _pump();
    _evaluateFlush();
  }

  StudentAnswerAutosave get _queue => _autosave ??= StudentAnswerAutosave(
    ref.read(studentAutosaveTimerFactoryProvider),
    _pump,
  );

  void _queueEveryDirtyQuestion() {
    for (final entry in state.questions.entries) {
      if (entry.value.isDirty && entry.value.validation == null) {
        _queue.dueNow(entry.key);
      }
    }
  }

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
    if (!ref.mounted || !state.hasUncertainMutation || state.isTerminal) return;
    final parent = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget),
    );
    if (parent.localTimeExpired) return;
    if (!_gateIsIdle || state.isReconciling) {
      _queue.scheduleRecovery(_recover);
      return;
    }
    unawaited(checkCurrentAttempt());
  }

  void _evaluateFlush() {
    if (_flush == null || !ref.mounted) return;
    final parent = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget),
    );
    if (!state.isEligible ||
        state.isTerminal ||
        state.hasUncertainMutation ||
        state.hasInvalidDraft ||
        state.hasFailedSave ||
        parent.localTimeExpired ||
        parent.status == StudentBlitzExecutionStatus.reconciliationFailed) {
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

  void _adoptSaved(String id, StudentAttemptAnswerMutationResult result) {
    final parent = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget),
    );
    final current = state.questions[id]!;
    final dirty = current.draft.isDirty(current.question, result.answer);
    // The local draft is never replaced: it may already hold newer typing.
    final saved = StudentBlitzAnswerEditorState(
      questions: {
        ...state.questions,
        id: StudentQuestionAnswerEditorState(
          question: current.question,
          serverAnswer: result.answer,
          updatedAt: result.updatedAt,
          draft: current.draft,
          saveStatus: dirty
              ? StudentAnswerSaveStatus.idle
              : StudentAnswerSaveStatus.saved,
        ),
      },
      isEligible: state.isEligible,
    );
    _lastPublication = parent.publicationToken;
    state = _synchronize(saved, parent);
    _queue.finished(id, dirty: dirty);
  }

  StudentBlitzAnswerEditorState _synchronize(
    StudentBlitzAnswerEditorState previous,
    StudentBlitzExecutionState parent,
  ) {
    final attempt = parent.attempt!;
    final terminal = attempt.status != StudentBlitzAttemptStatus.inProgress;
    if (previous.isTerminal && !terminal) return previous;
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
    return StudentBlitzAnswerEditorState(
      questions: questions,
      isEligible: true,
      isAuthoritative: _hasSaveAuthority(parent),
      isRunning: _isRunning(parent),
      activeQuestionId: terminal ? null : previous.activeQuestionId,
      pendingMutationSnapshot: terminal
          ? null
          : previous.pendingMutationSnapshot,
      isReconciling: !terminal && previous.isReconciling,
      isTerminal: terminal,
      sourcePublication: preservedUncertainty ? null : parent.publicationToken,
      isFlushing: _flush != null,
    );
  }

  StudentAttemptAnswerState? _answerFor(
    StudentBlitzAttempt attempt,
    String id,
  ) {
    for (final answer in attempt.answers) {
      if (answer.questionId.toLowerCase() == id) return answer;
    }
    return null;
  }

  bool _hasSaveAuthority(StudentBlitzExecutionState parent) =>
      !_cleared &&
      parent.acceptsWrites &&
      parent.attempt != null &&
      _matchesAttempt(parent.attempt!);

  bool _isRunning(StudentBlitzExecutionState parent) =>
      !_cleared &&
      parent.isExecuting &&
      !parent.localTimeExpired &&
      parent.attempt != null &&
      _matchesAttempt(parent.attempt!);

  bool _matchesAttempt(StudentBlitzAttempt attempt) =>
      attempt.id.toLowerCase() == target.attemptId &&
      attempt.assessmentId.toLowerCase() == target.routeTarget.blitzId;

  bool _canEdit(String id) {
    final key = _activeSessionKey;
    return _gateIsIdle &&
        key != null &&
        _matchesSession(key) &&
        state.canEdit(id);
  }

  bool get _gateIsIdle =>
      ref.read(studentBlitzExecutionOperationGateProvider(target)) ==
      StudentBlitzExecutionOperation.idle;

  bool _canPublish(
    int generation,
    StudentSessionKey key,
    String id,
    StudentAnswerMutation snapshot,
  ) =>
      ref.mounted &&
      _matchesSession(key) &&
      generation == _generation &&
      !state.isTerminal &&
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
    if (result.questionId.toLowerCase() != question.id.toLowerCase() ||
        result.type != question.type ||
        (result.answer == null) != (result.updatedAt == null)) {
      return false;
    }
    final answer = result.answer;
    if (answer == null) {
      return StudentAnswerDraft.fromAnswer(question, null).canClear;
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

  /// Rejections showing that the Attempt changed; `selection_limit_exceeded`
  /// and `validation_failed` stay Question-level and change nothing.
  static const _reconciledCodes = {
    ApiErrorCodes.blitzTimeExpired,
    ApiErrorCodes.blitzNotActive,
    ApiErrorCodes.attemptNotEditable,
    ApiErrorCodes.resourceNotFound,
    ApiErrorCodes.businessConflict,
  };

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
    _lastPublication = null;
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

  void _finishQuestion(String id, StudentQuestionAnswerEditorState entry) {
    state = StudentBlitzAnswerEditorState(
      questions: {...state.questions, id: entry},
      isEligible: state.isEligible,
      isAuthoritative: state.isAuthoritative,
      isRunning: state.isRunning,
      isTerminal: state.isTerminal,
      sourcePublication: state.sourcePublication,
      isFlushing: _flush != null,
    );
  }

  StudentBlitzAnswerEditorState _copyState(
    StudentBlitzAnswerEditorState previous, {
    Map<String, StudentQuestionAnswerEditorState>? questions,
    bool? isAuthoritative,
    bool? isRunning,
    String? activeQuestionId,
    StudentAnswerMutation? pendingMutationSnapshot,
    bool? isReconciling,
  }) => StudentBlitzAnswerEditorState(
    questions: questions ?? previous.questions,
    isEligible: _activeSessionKey != null && !_cleared,
    isAuthoritative: isAuthoritative ?? previous.isAuthoritative,
    isRunning: isRunning ?? previous.isRunning,
    activeQuestionId: activeQuestionId ?? previous.activeQuestionId,
    pendingMutationSnapshot:
        pendingMutationSnapshot ?? previous.pendingMutationSnapshot,
    isReconciling: isReconciling ?? previous.isReconciling,
    isTerminal: previous.isTerminal,
    sourcePublication: previous.sourcePublication,
    isFlushing: _flush != null,
  );
}
