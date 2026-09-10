import '../../../core/network/api_failure.dart';
import '../domain/student_homework.dart';
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
