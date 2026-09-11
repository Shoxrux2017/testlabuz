import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_controller.dart';
import '../domain/student_homework.dart';
import '../domain/student_homework_attempt.dart';
import '../domain/student_homework_attempt_route_target.dart';
import '../domain/student_question.dart';
import 'student_attempt_answer_editor_controller.dart';
import 'student_attempt_answer_editor_state.dart';
import 'student_attempt_route_operation_gate.dart';
import 'student_file_answer_controller.dart';
import 'student_file_answer_state.dart';
import 'student_homework_attempt_controller.dart';
import 'student_homework_attempt_state.dart';
import 'student_session_key.dart';

enum StudentHomeworkSubmitBlocker {
  attemptNotEditable,
  attemptStateLoading,
  nonFileUnsavedChanges,
  nonFileSaveInProgress,
  nonFileSaveUncertain,
  fileSelectionPending,
  fileUploadInProgress,
  fileUploadUncertain,
  localStateUnavailable,
}

class StudentHomeworkSubmitAnswerSnapshot {
  const StudentHomeworkSubmitAnswerSnapshot({
    required this.questionCount,
    required this.confirmedAnsweredCount,
  }) : assert(confirmedAnsweredCount >= 0),
       assert(confirmedAnsweredCount <= questionCount);

  final int questionCount;
  final int confirmedAnsweredCount;
  int get unansweredCount => questionCount - confirmedAnsweredCount;
}

class StudentHomeworkSubmitReadyToken {
  const StudentHomeworkSubmitReadyToken._({
    required this.sessionKey,
    required this.target,
    required this.publicationToken,
    required this.attempt,
    required this.answerState,
    required this.fileState,
    required this.snapshot,
  });

  final StudentSessionKey sessionKey;
  final StudentHomeworkAttemptRouteTarget target;
  final StudentHomeworkAttemptPublicationToken publicationToken;
  final StudentHomeworkAttempt attempt;
  final StudentAttemptAnswerEditorState answerState;
  final StudentFileAnswerState fileState;
  final StudentHomeworkSubmitAnswerSnapshot snapshot;

  bool matches(StudentHomeworkSubmitReadyToken other) =>
      sessionKey == other.sessionKey &&
      target == other.target &&
      identical(publicationToken, other.publicationToken) &&
      identical(attempt, other.attempt) &&
      identical(answerState, other.answerState) &&
      identical(fileState, other.fileState) &&
      snapshot.questionCount == other.snapshot.questionCount &&
      snapshot.confirmedAnsweredCount == other.snapshot.confirmedAnsweredCount;
}

final studentHomeworkSubmitReadinessProvider = Provider.autoDispose
    .family<StudentHomeworkSubmitReadiness, StudentHomeworkAttemptRouteTarget>(
      (ref, target) => StudentHomeworkSubmitReadiness.evaluate(
        sessionKey: StudentSessionSnapshot.fromSession(
          ref.watch(authSessionControllerProvider),
          ref.watch(appDeviceSurfaceProvider),
        ).eligibleKey,
        target: target,
        attemptState: ref.watch(
          studentHomeworkAttemptControllerProvider(target),
        ),
        answerState: ref.watch(
          studentAttemptAnswerEditorControllerProvider(target),
        ),
        fileState: ref.watch(studentFileAnswerControllerProvider(target)),
        operation: ref.watch(studentAttemptRouteOperationGateProvider(target)),
      ),
    );

class StudentHomeworkSubmitReadiness {
  StudentHomeworkSubmitReadiness._(
    Set<StudentHomeworkSubmitBlocker> blockers,
    this.readyToken,
  ) : blockers = Set.unmodifiable(blockers);

  final Set<StudentHomeworkSubmitBlocker> blockers;
  final StudentHomeworkSubmitReadyToken? readyToken;
  bool get isReady => readyToken != null;

  static StudentHomeworkSubmitReadiness evaluate({
    required StudentSessionKey? sessionKey,
    required StudentHomeworkAttemptRouteTarget target,
    required StudentHomeworkAttemptState attemptState,
    required StudentAttemptAnswerEditorState answerState,
    required StudentFileAnswerState fileState,
    required StudentAttemptRouteOperation operation,
  }) {
    final blockers = <StudentHomeworkSubmitBlocker>{};
    final attempt = attemptState.attempt;
    final publication = attemptState.publicationToken;
    if (attemptState.status == StudentHomeworkAttemptLoadStatus.initial ||
        attemptState.status == StudentHomeworkAttemptLoadStatus.loading ||
        attemptState.status == StudentHomeworkAttemptLoadStatus.refreshing ||
        operation != StudentAttemptRouteOperation.idle) {
      blockers.add(StudentHomeworkSubmitBlocker.attemptStateLoading);
    }
    if (sessionKey == null ||
        attemptState.status != StudentHomeworkAttemptLoadStatus.data ||
        attempt == null ||
        !isCanonicalStudentAttemptId(attempt.id) ||
        !isCanonicalStudentHomeworkId(attempt.assessmentId) ||
        attempt.id.toLowerCase() != target.attemptId ||
        attempt.assessmentId.toLowerCase() != target.homeworkId ||
        attempt.status != StudentHomeworkAttemptStatus.inProgress) {
      blockers.add(StudentHomeworkSubmitBlocker.attemptNotEditable);
    }
    if (publication == null ||
        !answerState.isEligible ||
        !answerState.isAuthoritative ||
        answerState.terminalAttempt != null ||
        !fileState.isAuthoritative ||
        fileState.isTerminal ||
        !identical(answerState.sourceAttemptPublication, publication) ||
        !identical(fileState.sourceAttemptPublication, publication) ||
        attempt == null ||
        !_questionsAlign(attempt, answerState, fileState)) {
      blockers.add(StudentHomeworkSubmitBlocker.localStateUnavailable);
    }
    if (answerState.hasDirtyDrafts) {
      blockers.add(StudentHomeworkSubmitBlocker.nonFileUnsavedChanges);
    }
    if (answerState.isReconciling ||
        answerState.activeQuestionId != null ||
        answerState.pendingMutationSnapshot != null ||
        answerState.questions.values.any(
          (entry) => entry.saveStatus == StudentAnswerSaveStatus.saving,
        )) {
      blockers.add(StudentHomeworkSubmitBlocker.nonFileSaveInProgress);
    }
    if (answerState.hasUncertainMutation) {
      blockers.add(StudentHomeworkSubmitBlocker.nonFileSaveUncertain);
    }
    if (fileState.hasPendingSelection) {
      blockers.add(StudentHomeworkSubmitBlocker.fileSelectionPending);
    }
    if (fileState.isReconciling ||
        fileState.activeQuestionId != null ||
        fileState.questions.values.any(
          (entry) =>
              entry.status == StudentFileAnswerStatus.selecting ||
              entry.status == StudentFileAnswerStatus.uploading,
        )) {
      blockers.add(StudentHomeworkSubmitBlocker.fileUploadInProgress);
    }
    if (fileState.hasUncertainUpload) {
      blockers.add(StudentHomeworkSubmitBlocker.fileUploadUncertain);
    }
    if (blockers.isNotEmpty) {
      return StudentHomeworkSubmitReadiness._(blockers, null);
    }
    final snapshot = StudentHomeworkSubmitAnswerSnapshot(
      questionCount: attempt!.questions.length,
      confirmedAnsweredCount:
          answerState.questions.values
              .where((entry) => entry.serverAnswer != null)
              .length +
          fileState.questions.values
              .where((entry) => entry.serverFile != null)
              .length,
    );
    return StudentHomeworkSubmitReadiness._(
      blockers,
      StudentHomeworkSubmitReadyToken._(
        sessionKey: sessionKey!,
        target: target,
        publicationToken: publication!,
        attempt: attempt,
        answerState: answerState,
        fileState: fileState,
        snapshot: snapshot,
      ),
    );
  }

  static bool _questionsAlign(
    StudentHomeworkAttempt attempt,
    StudentAttemptAnswerEditorState answers,
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
