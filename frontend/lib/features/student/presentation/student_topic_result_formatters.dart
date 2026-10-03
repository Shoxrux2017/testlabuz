import '../domain/student_topic_result.dart';

/// The Student-facing status of a Topic result (docs/04 Student result flow).
String studentTopicResultStatusLabel(StudentTopicResult result) {
  return switch (result.status) {
    StudentTopicResultStatus.waitingForHomework => 'Waiting for Homework',
    StudentTopicResultStatus.waitingForBlitz => 'Waiting for Blitz',
    StudentTopicResultStatus.waitingForTeacherReview =>
      'Waiting for Teacher review',
    StudentTopicResultStatus.waitingForSettings => 'Being prepared',
    StudentTopicResultStatus.calculated => 'Calculated',
    StudentTopicResultStatus.notCompleted => 'Not completed',
    StudentTopicResultStatus.closed => switch (result.closedOutcome!) {
      StudentTopicResultOutcome.calculated => 'Final',
      StudentTopicResultOutcome.notCompleted => 'Not completed (final)',
    },
  };
}

String studentTopicResultMissingLabel(
  StudentTopicResultMissingComponent component,
) {
  return switch (component) {
    StudentTopicResultMissingComponent.homework => 'Missing: Homework',
    StudentTopicResultMissingComponent.blitz => 'Missing: Blitz',
    StudentTopicResultMissingComponent.both => 'Missing: Homework and Blitz',
  };
}

/// One neutral line on how the final score was formed (S10-D2); never a
/// judgement about the difference between the two scores.
String studentTopicResultMethodLine(StudentTopicResultMethod method) {
  return switch (method) {
    StudentTopicResultMethod.average =>
      'The final score is the average of the Homework and Blitz scores.',
    StudentTopicResultMethod.blitz => 'The final score is the Blitz score.',
  };
}

/// Why no values are shown: an outcome waits for its release window or the
/// Teacher's release and is never presented as incomplete.
String studentTopicResultHiddenMessage(StudentTopicResult result) {
  return result.isOutcome
      ? 'The result is not open yet.'
      : 'Scores appear when the result is ready.';
}
