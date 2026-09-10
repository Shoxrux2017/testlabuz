import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../domain/student_homework.dart';
import '../domain/student_homework_attempt.dart';
import '../domain/student_question.dart';

String studentHomeworkStatusLabel(StudentHomeworkStatus status) {
  return switch (status) {
    StudentHomeworkStatus.active => 'Active',
    StudentHomeworkStatus.closed => 'Closed',
    StudentHomeworkStatus.archived => 'Archived',
  };
}

String studentHomeworkMyStatusLabel(StudentHomeworkMyStatus status) {
  return switch (status) {
    StudentHomeworkMyStatus.notStarted => 'Not started',
    StudentHomeworkMyStatus.inProgress => 'In progress',
    StudentHomeworkMyStatus.submitted => 'Submitted',
    StudentHomeworkMyStatus.waitingForReview => 'Waiting for review',
    StudentHomeworkMyStatus.checked => 'Checked',
  };
}

String studentQuestionTypeLabel(StudentQuestionType type) {
  return switch (type) {
    StudentQuestionType.singleChoice => 'Single choice',
    StudentQuestionType.multipleChoice => 'Multiple choice',
    StudentQuestionType.trueFalse => 'True / False',
    StudentQuestionType.shortWritten => 'Short answer',
    StudentQuestionType.openWritten => 'Written answer',
    StudentQuestionType.fileBased => 'File upload',
    StudentQuestionType.matching => 'Matching',
    StudentQuestionType.ordering => 'Ordering',
    StudentQuestionType.fillInBlank => 'Fill in the blank',
  };
}

String formatStudentHomeworkPoints(num points) =>
    points == points.roundToDouble()
    ? points.toStringAsFixed(0)
    : points.toString();

String studentHomeworkFailureMessage(ApiFailure failure) {
  return switch (failure.kind) {
    ApiFailureKind.connection =>
      'Could not reach the server. Check the connection and try again.',
    ApiFailureKind.timeout => 'The Homework request timed out.',
    ApiFailureKind.invalidResponse =>
      'The server returned an unexpected Homework response.',
    _ => 'Homework could not be loaded. Try again.',
  };
}

String studentHomeworkAttemptStatusLabel(StudentHomeworkAttemptStatus status) =>
    switch (status) {
      StudentHomeworkAttemptStatus.inProgress => 'In progress',
      StudentHomeworkAttemptStatus.submitted => 'Submitted',
      StudentHomeworkAttemptStatus.waitingForReview => 'Waiting for review',
      StudentHomeworkAttemptStatus.checked => 'Checked',
    };

String studentHomeworkAttemptFinalizationLabel(
  StudentHomeworkAttemptFinalizationReason reason,
) => switch (reason) {
  StudentHomeworkAttemptFinalizationReason.studentSubmit => 'Submitted by you',
  StudentHomeworkAttemptFinalizationReason.homeworkDeadline =>
    'Homework deadline reached',
  StudentHomeworkAttemptFinalizationReason.taskClosed => 'Homework closed',
};

String studentHomeworkAttemptFailureMessage(ApiFailure failure) =>
    switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The Attempt request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected Attempt response.',
      _ => 'The Attempt could not be loaded. Try again.',
    };

String studentHomeworkStartFailureMessage(ApiFailure failure) =>
    switch (failure.serverCode) {
      ApiErrorCodes.deadlinePassed => 'The Homework deadline has passed.',
      ApiErrorCodes.attemptsExhausted => 'No Homework attempts remain.',
      ApiErrorCodes.taskNotActive ||
      ApiErrorCodes.taskClosed ||
      ApiErrorCodes.taskArchived =>
        'This Homework is no longer available for a new attempt.',
      ApiErrorCodes.assessmentNotAssigned =>
        'This Homework is no longer assigned to you.',
      ApiErrorCodes.resourceNotFound => 'This Homework is no longer available.',
      ApiErrorCodes.idempotencyKeyReused =>
        'The attempt could not be started safely. Refresh and try again.',
      ApiErrorCodes.businessConflict =>
        'The attempt could not be started because Homework state changed. '
            'Refresh and try again.',
      _ => 'The attempt could not be started. Refresh and try again.',
    };

String studentAnswerSaveFailureMessage(ApiFailure failure) =>
    switch (failure.serverCode) {
      ApiErrorCodes.selectionLimitExceeded => 'Too many options are selected.',
      ApiErrorCodes.validationFailed =>
        'Review your answer before saving again.',
      ApiErrorCodes.deadlinePassed => 'The Homework deadline has passed.',
      ApiErrorCodes.attemptNotEditable => 'This attempt is no longer editable.',
      ApiErrorCodes.taskClosed ||
      ApiErrorCodes.taskArchived ||
      ApiErrorCodes.taskNotActive => 'This Homework is no longer editable.',
      ApiErrorCodes.resourceNotFound => 'This Attempt is no longer available.',
      ApiErrorCodes.businessConflict =>
        'The Attempt changed. Review its reloaded state before saving again.',
      _ => 'Your draft has been kept. Review it before saving again.',
    };
