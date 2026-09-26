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
  var _generation = 0;
  var _cleared = false;

  @override
  StudentBlitzAnswerEditorState build() {
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
      return StudentBlitzAnswerEditorState();
    }
    final previous = resetScope ? StudentBlitzAnswerEditorState() : state;
    final publication = parent.publicationToken;
    if (publication != null && !identical(publication, _lastPublication)) {
      _lastPublication = publication;
      return _synchronize(previous, parent);
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

  /// Leaving discards only unsaved local drafts; nothing is sent.
  void clearLocalState() {
    final clearedSession = _activeSessionKey;
    _invalidateOwnership();
    _activeSessionKey = clearedSession;
    _cleared = true;
    state = StudentBlitzAnswerEditorState();
  }

  /// Sends one non-idempotent answer PUT; it is never retried automatically.
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
    final write = execution.beginWrite();
    if (write == null) return;

    final entry = state.questions[id]!;
    final snapshot = entry.draft.toMutation(entry.question);
    final mutationPublication = state.sourcePublication;
    final generation = ++_generation;
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
        expectedPublication: mutationPublication,
      );
      if (!accepted) {
        // The parent moved on meanwhile; only the replay may show the result.
        _replaceQuestion(
          id,
          _withStatus(
            state.questions[id]!,
            StudentAnswerSaveStatus.uncertain,
            _invalidResponse().failure,
          ),
        );
        unawaited(checkCurrentAttempt());
        return;
      }
      _adoptSaved(id, result);
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
        return;
      }
      _finishQuestion(
        id,
        _withStatus(current, StudentAnswerSaveStatus.failure, failure),
      );
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
      return;
    }
    final question = questions.single;
    final answer = _answerFor(attempt, id);
    final pendingDraft = StudentAnswerDraft.fromMutation(question, snapshot);
    final differs = pendingDraft.isDirty(question, answer?.value);
    final resolved = StudentBlitzAnswerEditorState(
      questions: {
        ...state.questions,
        id: StudentQuestionAnswerEditorState(
          question: question,
          serverAnswer: answer?.value,
          updatedAt: answer?.updatedAt,
          // A different server answer is adopted; the unsent draft stays for
          // an explicit review and Save, never an automatic resend.
          draft: differs
              ? pendingDraft
              : StudentAnswerDraft.fromAnswer(question, answer?.value),
          saveStatus: differs
              ? StudentAnswerSaveStatus.idle
              : StudentAnswerSaveStatus.saved,
        ),
      },
      isEligible: state.isEligible,
    );
    _lastPublication = parent.publicationToken;
    state = _synchronize(resolved, parent);
  }

  void _adoptSaved(String id, StudentAttemptAnswerMutationResult result) {
    final parent = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget),
    );
    final current = state.questions[id]!;
    final saved = StudentBlitzAnswerEditorState(
      questions: {
        ...state.questions,
        id: StudentQuestionAnswerEditorState(
          question: current.question,
          serverAnswer: result.answer,
          updatedAt: result.updatedAt,
          draft: StudentAnswerDraft.fromAnswer(current.question, result.answer),
          saveStatus: StudentAnswerSaveStatus.saved,
        ),
      },
      isEligible: state.isEligible,
    );
    _lastPublication = parent.publicationToken;
    state = _synchronize(saved, parent);
  }

  StudentBlitzAnswerEditorState _synchronize(
    StudentBlitzAnswerEditorState previous,
    StudentBlitzExecutionState parent,
  ) {
    final attempt = parent.attempt!;
    final terminal = attempt.status != StudentBlitzAttemptStatus.inProgress;
    if (previous.isTerminal && !terminal) return previous;
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
    return StudentBlitzAnswerEditorState(
      questions: questions,
      isEligible: true,
      isAuthoritative: _hasSaveAuthority(parent),
      activeQuestionId: terminal ? null : previous.activeQuestionId,
      pendingMutationSnapshot: terminal
          ? null
          : previous.pendingMutationSnapshot,
      isReconciling: !terminal && previous.isReconciling,
      isTerminal: terminal,
      sourcePublication: preservedUncertainty ? null : parent.publicationToken,
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
      isTerminal: state.isTerminal,
      sourcePublication: state.sourcePublication,
    );
  }

  StudentBlitzAnswerEditorState _copyState(
    StudentBlitzAnswerEditorState previous, {
    Map<String, StudentQuestionAnswerEditorState>? questions,
    bool? isAuthoritative,
    String? activeQuestionId,
    StudentAnswerMutation? pendingMutationSnapshot,
    bool? isReconciling,
  }) => StudentBlitzAnswerEditorState(
    questions: questions ?? previous.questions,
    isEligible: _activeSessionKey != null && !_cleared,
    isAuthoritative: isAuthoritative ?? previous.isAuthoritative,
    activeQuestionId: activeQuestionId ?? previous.activeQuestionId,
    pendingMutationSnapshot:
        pendingMutationSnapshot ?? previous.pendingMutationSnapshot,
    isReconciling: isReconciling ?? previous.isReconciling,
    isTerminal: previous.isTerminal,
    sourcePublication: previous.sourcePublication,
  );
}
