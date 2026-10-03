import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/scoring/score_display.dart';
import '../domain/student_homework.dart';
import '../domain/student_homework_attempt.dart';
import '../application/student_homework_submit_readiness.dart';
import '../domain/student_question.dart';
import '../domain/student_submission_upload.dart';

/// `Score <one decimal>` for a released Attempt result (`S09-T3`), or null
/// while it is hidden.
String? studentAttemptScoreLabel(StudentAttemptResult result) {
  // A hidden result never carries a score.
  final score = result.normalizedScore;
  return score == null ? null : 'Score ${formatScoreOneDecimal(score)}';
}

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
    'Finalized at the Homework deadline',
  StudentHomeworkAttemptFinalizationReason.taskClosed =>
    'Finalized when the Homework was closed',
};

String studentHomeworkSubmitBlockerMessage(
  StudentHomeworkSubmitBlocker blocker,
) => switch (blocker) {
  StudentHomeworkSubmitBlocker.attemptNotEditable =>
    'This Attempt is not available for submission.',
  StudentHomeworkSubmitBlocker.attemptStateLoading =>
    'Wait for the Attempt refresh to finish.',
  StudentHomeworkSubmitBlocker.nonFileUnsavedChanges =>
    'Some answers are still being saved.',
  StudentHomeworkSubmitBlocker.nonFileSaveInProgress =>
    'An answer is being saved.',
  StudentHomeworkSubmitBlocker.nonFileSaveUncertain =>
    'An answer save is not confirmed yet. It is being checked.',
  StudentHomeworkSubmitBlocker.nonFileInvalidAnswer =>
    'Fix the marked answers before submitting.',
  StudentHomeworkSubmitBlocker.nonFileSaveFailed =>
    'Some answers were not saved. Check the marked questions.',
  StudentHomeworkSubmitBlocker.fileSelectionPending =>
    'Retry or cancel the file that was not uploaded.',
  StudentHomeworkSubmitBlocker.fileUploadInProgress =>
    'Wait for the current file operation to finish.',
  StudentHomeworkSubmitBlocker.fileUploadUncertain =>
    'Resolve the unconfirmed file upload before submitting.',
  StudentHomeworkSubmitBlocker.localStateUnavailable =>
    'Refresh the Attempt to confirm the current saved answers before submitting.',
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
      ApiErrorCodes.resultClosed =>
        'Your Topic result is closed, so a new Homework attempt cannot be '
            'started.',
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

String formatStudentSubmissionBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes bytes';
}

String studentSubmissionSelectionErrorMessage(
  StudentSubmissionSelectionError error,
) => switch (error) {
  StudentSubmissionSelectionError.emptyFile => 'The selected file is empty.',
  StudentSubmissionSelectionError.unsupportedExtension =>
    'Choose a file with an allowed extension.',
  StudentSubmissionSelectionError.tooLarge =>
    'The selected file exceeds the current upload limit.',
  StudentSubmissionSelectionError.filenameTooLong =>
    'The filename must contain no more than 500 characters.',
  StudentSubmissionSelectionError.invalidFilename =>
    'Choose a file with a valid filename.',
};

String studentFileAnswerFailureMessage(
  ApiFailure failure,
) => switch (failure.serverCode) {
  ApiErrorCodes.unsupportedFileType =>
    'The selected file content is not a supported PDF, DOCX, PPT, or PPTX file.',
  ApiErrorCodes.fileTooLarge =>
    'The selected file exceeds the current upload limit.',
  ApiErrorCodes.fileUploadFailed => 'The file could not be stored. Try again.',
  ApiErrorCodes.validationFailed =>
    'The file answer could not be accepted. Choose a file again.',
  ApiErrorCodes.deadlinePassed => 'The Homework deadline has passed.',
  ApiErrorCodes.attemptNotEditable => 'This attempt is no longer editable.',
  ApiErrorCodes.taskNotActive ||
  ApiErrorCodes.taskClosed ||
  ApiErrorCodes.taskArchived => 'This Homework is no longer editable.',
  ApiErrorCodes.resourceNotFound => 'This Attempt is no longer available.',
  ApiErrorCodes.businessConflict =>
    'The Attempt changed. Review its reloaded state before uploading again.',
  _ => 'The file answer could not be uploaded. Choose a file again.',
};
