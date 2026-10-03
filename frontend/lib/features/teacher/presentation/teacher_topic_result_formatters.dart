import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/scoring/score_display.dart';
import '../domain/teacher_topic_result.dart';
import 'teacher_topic_formatters.dart';

const teacherTopicResultsEmptyMessage =
    'No results yet. Results appear once the official Homework is activated.';

String teacherTopicResultStatusLabel(TeacherTopicResultStatus status) {
  return switch (status) {
    TeacherTopicResultStatus.waitingForHomework => 'Waiting for Homework',
    TeacherTopicResultStatus.waitingForBlitz => 'Waiting for Blitz',
    TeacherTopicResultStatus.waitingForTeacherReview => 'Waiting for review',
    TeacherTopicResultStatus.waitingForSettings =>
      'Waiting for result settings',
    TeacherTopicResultStatus.calculated => 'Calculated',
    TeacherTopicResultStatus.notCompleted => 'Not completed',
    TeacherTopicResultStatus.closed => 'Closed',
  };
}

/// The status of one result; a closed result also names its outcome.
String teacherTopicResultLabel(TeacherTopicResult result) {
  return switch (result.closedOutcome) {
    TeacherTopicResultOutcome.calculated => 'Closed · Calculated',
    TeacherTopicResultOutcome.notCompleted => 'Closed · Not completed',
    null => teacherTopicResultStatusLabel(result.status),
  };
}

String teacherTopicResultSideStateLabel(TeacherTopicResultSideState state) {
  return switch (state) {
    TeacherTopicResultSideState.ready => 'Ready',
    TeacherTopicResultSideState.waitingForTeacherReview => 'Waiting for review',
    TeacherTopicResultSideState.checking => 'Checking',
    TeacherTopicResultSideState.notActivated => 'Not activated',
    TeacherTopicResultSideState.open => 'Open',
    TeacherTopicResultSideState.missing => 'Missing',
    TeacherTopicResultSideState.notDesignated => 'No official Blitz',
  };
}

String teacherTopicResultMissingLabel(
  TeacherTopicResultMissingComponent component,
) {
  return switch (component) {
    TeacherTopicResultMissingComponent.homework => 'Missing: Homework',
    TeacherTopicResultMissingComponent.blitz => 'Missing: Blitz',
    TeacherTopicResultMissingComponent.both => 'Missing: Homework and Blitz',
  };
}

/// Explains which score became final without judging the Student.
String teacherTopicResultComparisonMessage(
  TeacherTopicResultConsistency consistency,
) {
  return switch (consistency) {
    TeacherTopicResultConsistency.consistent =>
      'The scores are within the allowed difference, so the final score is '
          'their average.',
    TeacherTopicResultConsistency.inconsistent =>
      'The scores differ by more than the allowed difference, so the Blitz '
          'score is used.',
  };
}

String teacherTopicResultMethodLabel(TeacherTopicResultMethod method) {
  return switch (method) {
    TeacherTopicResultMethod.average => 'Average of both scores',
    TeacherTopicResultMethod.blitz => 'Blitz score',
  };
}

const teacherTopicResultSettingsMessage =
    'The Institution Admin has not set the allowed difference or the '
    'categories yet.';

/// Filter labels for the five fixed category codes; rows show the server's
/// label.
String teacherTopicResultCategoryFilterLabel(
  TeacherTopicResultCategoryCode code,
) {
  return switch (code) {
    TeacherTopicResultCategoryCode.understoodWell => 'Understood well',
    TeacherTopicResultCategoryCode.partiallyUnderstood =>
      'Partially understood',
    TeacherTopicResultCategoryCode.needsRevision => 'Needs revision',
    TeacherTopicResultCategoryCode.needsTeacherSupport =>
      'Needs teacher support',
    TeacherTopicResultCategoryCode.notCompleted => 'Not completed',
  };
}

String teacherStudentReleaseModeLabel(TeacherStudentResultReleaseMode? mode) {
  return switch (mode) {
    TeacherStudentResultReleaseMode.automatic => 'Automatic',
    TeacherStudentResultReleaseMode.manualTeacher => 'Manual by the Teacher',
    null => 'Not configured',
  };
}

String teacherParentReleaseModeLabel(TeacherParentResultReleaseMode? mode) {
  return switch (mode) {
    TeacherParentResultReleaseMode.withStudent => 'With the Student',
    TeacherParentResultReleaseMode.manualTeacher => 'Manual by the Teacher',
    TeacherParentResultReleaseMode.hidden => 'Hidden from Parents',
    null => 'Not configured',
  };
}

String teacherTopicResultClosureReasonLabel(
  TeacherTopicResultClosureReason reason,
) {
  return switch (reason) {
    TeacherTopicResultClosureReason.teacher => 'Closed by the Teacher',
    TeacherTopicResultClosureReason.topicArchived =>
      'Closed when the Topic was archived',
  };
}

String teacherTopicResultVisibilityLabel(bool visible) {
  return visible ? 'Visible' : 'Not visible';
}

/// "Homework 88.0 · Blitz 84.0 · Final 86.0" with the present values only.
String? teacherTopicResultScoresLine(TeacherTopicResult result) {
  final parts = [
    if (result.homework.score case final score?)
      'Homework ${formatScoreOneDecimal(score)}',
    if (result.blitz.score case final score?)
      'Blitz ${formatScoreOneDecimal(score)}',
    if (result.finalScore case final score?)
      'Final ${formatScoreOneDecimal(score)}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// An instant in the Institution timezone, or in UTC when it is unknown.
String formatTeacherResultTime(DateTime instant, String? timezone) {
  return (timezone == null
          ? null
          : formatInstitutionInstant(instant, timezone)) ??
      formatUtcInstant(instant);
}

String teacherTopicResultsFailureMessage(ApiFailure failure) {
  return _failureMessage(
    failure,
    notFound: 'These Topic results are not available.',
    fallback: 'Topic results could not be loaded.',
  );
}

String teacherTopicResultFailureMessage(ApiFailure failure) {
  return _failureMessage(
    failure,
    notFound: 'This result is not available.',
    fallback: 'The result could not be loaded.',
  );
}

String _failureMessage(
  ApiFailure failure, {
  required String notFound,
  required String fallback,
}) {
  if (failure.statusCode == 404 &&
      failure.serverCode == ApiErrorCodes.resourceNotFound) {
    return notFound;
  }
  return switch (failure.kind) {
    ApiFailureKind.connection =>
      'Could not reach the server. Check the connection and try again.',
    ApiFailureKind.timeout => 'The request timed out. Try again.',
    ApiFailureKind.invalidResponse =>
      'The server returned an unexpected result response.',
    _ => fallback,
  };
}
