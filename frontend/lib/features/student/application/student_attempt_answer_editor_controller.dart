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
  var _generation = 0;
  var _cleared = false;

  @override
  StudentAttemptAnswerEditorState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final parent = ref.watch(studentHomeworkAttemptControllerProvider(target));
    if (key == null) {
      _invalidateOwnership();
      return StudentAttemptAnswerEditorState();
    }
    final changedSession = _activeSessionKey != key;
    if (changedSession) {
      _invalidateOwnership();
      _activeSessionKey = key;
      _cleared = false;
    }
    if (_cleared) return StudentAttemptAnswerEditorState();
    final previous = changedSession ? StudentAttemptAnswerEditorState() : state;
    final changedParent = !identical(parent, _lastParent);
    _lastParent = parent;
    if (changedParent &&
        parent.status == StudentHomeworkAttemptLoadStatus.data &&
        parent.attempt != null &&
        _matchesAttempt(parent.attempt!)) {
      return _synchronize(
        previous,
        parent.attempt!,
        sourcePublication: parent.publicationToken,
      );
    }
    return _copyState(previous, isAuthoritative: _hasSaveAuthority(parent));
  }

  void updateDraft(String questionId, StudentAnswerDraft draft) {
    final id = questionId.toLowerCase();
    if (!_canEdit(id)) return;
    final entry = state.questions[id]!;
    _replaceQuestion(
      id,
      StudentQuestionAnswerEditorState(
        question: entry.question,
        serverAnswer: entry.serverAnswer,
        updatedAt: entry.updatedAt,
        draft: draft,
      ),
    );
  }

  void discardChanges(String questionId) {
    final id = questionId.toLowerCase();
    if (!_canEdit(id)) return;
    final entry = state.questions[id]!;
    updateDraft(
      id,
      StudentAnswerDraft.fromAnswer(entry.question, entry.serverAnswer),
    );
  }

  void clearAnswer(String questionId) {
    final id = questionId.toLowerCase();
    if (!_canEdit(id)) return;
    final entry = state.questions[id]!;
    if (entry.draft.canClear) {
      updateDraft(id, entry.draft.clear(entry.question));
    }
  }

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
    final generation = ++_generation;
    final requestTarget = target;
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
      _finishQuestion(
        id,
        StudentQuestionAnswerEditorState(
          question: current.question,
          serverAnswer: result.answer,
          updatedAt: result.updatedAt,
          draft: StudentAnswerDraft.fromAnswer(current.question, result.answer),
          saveStatus: StudentAnswerSaveStatus.saved,
        ),
        preservePublication: identical(
          mutationPublication,
          state.sourceAttemptPublication,
        ),
      );
      _refreshAttempt();
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
      } else {
        _finishQuestion(
          id,
          _withStatus(current, StudentAnswerSaveStatus.failure, failure),
        );
        _reconcileFailure(failure);
      }
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
      final pendingDraft = StudentAnswerDraft.fromMutation(question, snapshot);
      final differs = pendingDraft.isDirty(question, answer?.value);
      final refreshed = _synchronize(state, attempt);
      state = _copyState(refreshed, isAuthoritative: false);
      _finishQuestion(
        id,
        StudentQuestionAnswerEditorState(
          question: question,
          serverAnswer: answer?.value,
          updatedAt: answer?.updatedAt,
          draft: differs
              ? pendingDraft
              : StudentAnswerDraft.fromAnswer(question, answer?.value),
          saveStatus: differs
              ? StudentAnswerSaveStatus.idle
              : StudentAnswerSaveStatus.saved,
        ),
      );
      _refreshAttempt();
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
    }
  }

  StudentAttemptAnswerEditorState _synchronize(
    StudentAttemptAnswerEditorState previous,
    StudentHomeworkAttempt attempt, {
    StudentHomeworkAttemptPublicationToken? sourcePublication,
  }) {
    final terminal = attempt.status != StudentHomeworkAttemptStatus.inProgress;
    if (previous.terminalAttempt != null && !terminal) return previous;
    if (terminal) _generation += 1;
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
      final preserveDraft =
          !terminal &&
          previousQuestion != null &&
          (previousQuestion.isDirty ||
              previousQuestion.saveStatus == StudentAnswerSaveStatus.saving);
      questions[id] = StudentQuestionAnswerEditorState(
        question: question,
        serverAnswer: answer?.value,
        updatedAt: answer?.updatedAt,
        draft: preserveDraft
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
  );
}
