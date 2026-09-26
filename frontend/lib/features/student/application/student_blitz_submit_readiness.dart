import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_controller.dart';
import '../domain/student_blitz.dart';
import '../domain/student_blitz_attempt.dart';
import '../domain/student_blitz_execution_target.dart';
import '../domain/student_question.dart';
import 'student_attempt_answer_editor_state.dart';
import 'student_attempt_publication_token.dart';
import 'student_blitz_answer_editor_controller.dart';
import 'student_blitz_answer_editor_state.dart';
import 'student_blitz_execution_controller.dart';
import 'student_blitz_execution_operation_gate.dart';
import 'student_blitz_execution_state.dart';
import 'student_blitz_file_answer_controller.dart';
import 'student_file_answer_state.dart';
import 'student_session_key.dart';

/// Why Submit is not available now. Unanswered Questions are never a blocker.
enum StudentBlitzSubmitBlocker {
  attemptNotEditable,
  attemptStateRefreshing,
  localTimeExpired,
  nonFileUnsavedChanges,
  nonFileSaveInProgress,
  nonFileSaveUncertain,
  fileSelectionPending,
  fileUploadInProgress,
  fileUploadUncertain,
  operationBusy,
  localStateUnavailable,
}

/// Presentation-only count of server-confirmed answers; never a score.
class StudentBlitzSubmitAnswerSnapshot {
  const StudentBlitzSubmitAnswerSnapshot({
    required this.questionCount,
    required this.confirmedAnsweredCount,
  }) : assert(confirmedAnsweredCount >= 0),
       assert(confirmedAnsweredCount <= questionCount);

  final int questionCount;
  final int confirmedAnsweredCount;
  int get unansweredCount => questionCount - confirmedAnsweredCount;
}

/// Everything a Submit confirmation was shown for. Submit proceeds only when
/// the token captured at dialog open still matches the current one.
class StudentBlitzSubmitReadyToken {
  const StudentBlitzSubmitReadyToken._({
    required this.sessionKey,
    required this.target,
    required this.publicationToken,
    required this.attempt,
    required this.answerState,
    required this.fileState,
    required this.snapshot,
    required this.countdownAnchor,
  });

  final StudentSessionKey sessionKey;
  final StudentBlitzExecutionTarget target;
  final StudentAttemptPublicationToken publicationToken;
  final StudentBlitzAttempt attempt;
  final StudentBlitzAnswerEditorState answerState;
  final StudentFileAnswerState fileState;
  final StudentBlitzSubmitAnswerSnapshot snapshot;
  final StudentBlitzCountdownAnchor? countdownAnchor;

  bool matches(StudentBlitzSubmitReadyToken other) =>
      sessionKey == other.sessionKey &&
      target == other.target &&
      identical(publicationToken, other.publicationToken) &&
      identical(attempt, other.attempt) &&
      identical(answerState, other.answerState) &&
      identical(fileState, other.fileState) &&
      snapshot.questionCount == other.snapshot.questionCount &&
      snapshot.confirmedAnsweredCount ==
          other.snapshot.confirmedAnsweredCount &&
      countdownAnchor == other.countdownAnchor;
}

final studentBlitzSubmitReadinessProvider = Provider.autoDispose
    .family<StudentBlitzSubmitReadiness, StudentBlitzExecutionTarget>(
      (ref, target) => StudentBlitzSubmitReadiness.evaluate(
        sessionKey: StudentSessionSnapshot.fromSession(
          ref.watch(authSessionControllerProvider),
          ref.watch(appDeviceSurfaceProvider),
        ).eligibleKey,
        target: target,
        execution: ref.watch(
          studentBlitzExecutionControllerProvider(target.routeTarget),
        ),
        answerState: ref.watch(
          studentBlitzAnswerEditorControllerProvider(target),
        ),
        fileState: ref.watch(studentBlitzFileAnswerControllerProvider(target)),
        operation: ref.watch(
          studentBlitzExecutionOperationGateProvider(target),
        ),
      ),
    );

class StudentBlitzSubmitReadiness {
  StudentBlitzSubmitReadiness._(
    Set<StudentBlitzSubmitBlocker> blockers,
    this.readyToken,
  ) : blockers = Set.unmodifiable(blockers);

  final Set<StudentBlitzSubmitBlocker> blockers;
  final StudentBlitzSubmitReadyToken? readyToken;
  bool get isReady => readyToken != null;

  static StudentBlitzSubmitReadiness evaluate({
    required StudentSessionKey? sessionKey,
    required StudentBlitzExecutionTarget target,
    required StudentBlitzExecutionState execution,
    required StudentBlitzAnswerEditorState answerState,
    required StudentFileAnswerState fileState,
    required StudentBlitzExecutionOperation operation,
  }) {
    final blockers = <StudentBlitzSubmitBlocker>{};
    final attempt = execution.attempt;
    final publication = execution.publicationToken;
    if (sessionKey == null ||
        attempt == null ||
        attempt.id.toLowerCase() != target.attemptId ||
        attempt.assessmentId.toLowerCase() != target.routeTarget.blitzId ||
        attempt.status != StudentBlitzAttemptStatus.inProgress ||
        !execution.isExecuting) {
      blockers.add(StudentBlitzSubmitBlocker.attemptNotEditable);
    } else if (execution.status != StudentBlitzExecutionStatus.active) {
      blockers.add(StudentBlitzSubmitBlocker.attemptStateRefreshing);
    }
    if (execution.localTimeExpired) {
      blockers.add(StudentBlitzSubmitBlocker.localTimeExpired);
    }
    if (operation != StudentBlitzExecutionOperation.idle) {
      blockers.add(StudentBlitzSubmitBlocker.operationBusy);
    }
    if (publication == null ||
        !answerState.isEligible ||
        answerState.isTerminal ||
        fileState.isTerminal ||
        !identical(answerState.sourcePublication, publication) ||
        !identical(fileState.sourceAttemptPublication, publication) ||
        attempt == null ||
        !_questionsAlign(attempt, answerState, fileState)) {
      blockers.add(StudentBlitzSubmitBlocker.localStateUnavailable);
    }
    if (answerState.hasDirtyDrafts) {
      blockers.add(StudentBlitzSubmitBlocker.nonFileUnsavedChanges);
    }
    if (answerState.isReconciling ||
        answerState.activeQuestionId != null ||
        answerState.pendingMutationSnapshot != null ||
        answerState.questions.values.any(
          (entry) => entry.saveStatus == StudentAnswerSaveStatus.saving,
        )) {
      blockers.add(StudentBlitzSubmitBlocker.nonFileSaveInProgress);
    }
    if (answerState.hasUncertainMutation) {
      blockers.add(StudentBlitzSubmitBlocker.nonFileSaveUncertain);
    }
    if (fileState.hasPendingSelection) {
      blockers.add(StudentBlitzSubmitBlocker.fileSelectionPending);
    }
    if (fileState.isReconciling ||
        fileState.activeQuestionId != null ||
        fileState.questions.values.any(
          (entry) =>
              entry.status == StudentFileAnswerStatus.selecting ||
              entry.status == StudentFileAnswerStatus.uploading,
        )) {
      blockers.add(StudentBlitzSubmitBlocker.fileUploadInProgress);
    }
    if (fileState.hasUncertainUpload) {
      blockers.add(StudentBlitzSubmitBlocker.fileUploadUncertain);
    }
    if (blockers.isNotEmpty) {
      return StudentBlitzSubmitReadiness._(blockers, null);
    }
    final snapshot = StudentBlitzSubmitAnswerSnapshot(
      questionCount: attempt!.questions.length,
      confirmedAnsweredCount:
          answerState.questions.values
              .where((entry) => entry.serverAnswer != null)
              .length +
          fileState.questions.values
              .where((entry) => entry.serverFile != null)
              .length,
    );
    return StudentBlitzSubmitReadiness._(
      blockers,
      StudentBlitzSubmitReadyToken._(
        sessionKey: sessionKey!,
        target: target,
        publicationToken: publication!,
        attempt: attempt,
        answerState: answerState,
        fileState: fileState,
        snapshot: snapshot,
        countdownAnchor: execution.countdownAnchor,
      ),
    );
  }

  static bool _questionsAlign(
    StudentBlitzAttempt attempt,
    StudentBlitzAnswerEditorState answers,
    StudentFileAnswerState files,
  ) {
    final nonFileQuestions = <String, StudentQuestion>{};
    final fileQuestions = <String, StudentQuestion>{};
    final seen = <String>{};
    for (final question in attempt.questions) {
      final id = question.id.toLowerCase();
      if (!seen.add(id)) return false;
      (question.type == StudentQuestionType.fileBased
              ? fileQuestions
              : nonFileQuestions)[id] =
          question;
    }
    if (answers.questions.length != nonFileQuestions.length ||
        files.questions.length != fileQuestions.length) {
      return false;
    }
    for (final entry in answers.questions.entries) {
      final expected = nonFileQuestions[entry.key];
      if (expected == null ||
          entry.value.question.id.toLowerCase() != entry.key ||
          entry.value.question.type != expected.type) {
        return false;
      }
    }
    for (final entry in files.questions.entries) {
      final expected = fileQuestions[entry.key];
      if (expected == null ||
          entry.value.question.id.toLowerCase() != entry.key ||
          entry.value.question.type != expected.type) {
        return false;
      }
    }
    return true;
  }
}
