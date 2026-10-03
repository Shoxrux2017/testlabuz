import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../domain/teacher_topic_result_mutation.dart';
import 'teacher_topic_result_bulk_action_state.dart';

const teacherTopicResultActionUnknownMessage =
    'The result could not be confirmed and was reloaded. Check it before '
    'trying again.';

const teacherTopicResultBulkActionUnknownMessage =
    'The results could not be confirmed and were reloaded. Check them before '
    'trying again.';

/// The explanation of a definite action failure; the server's own message is
/// never shown.
String teacherTopicResultActionFailureMessage(
  ApiFailure failure, {
  required bool bulk,
}) {
  if (failure.statusCode == 404 &&
      failure.serverCode == ApiErrorCodes.resourceNotFound) {
    return bulk
        ? 'These Topic results are no longer available.'
        : 'This result is no longer available.';
  }
  return switch (failure.serverCode) {
    ApiErrorCodes.manualReleaseNotAllowed =>
      "The Institution's release mode does not allow a Teacher release.",
    ApiErrorCodes.resultNotReady =>
      'This result is not ready to be released yet.',
    ApiErrorCodes.studentResultNotReleased =>
      'Parents can see the result only after the Student can.',
    ApiErrorCodes.resultNotReadyForClosure =>
      'This result cannot be closed yet.',
    ApiErrorCodes.resultClosed =>
      'This result is closed, so its comment cannot change.',
    ApiErrorCodes.validationFailed =>
      'The comment could not be saved. Check it and try again.',
    ApiErrorCodes.rateLimited =>
      'Too many requests. Wait a moment and try again.',
    _ => 'The action could not be completed. Try again.',
  };
}

/// A rejected body or a rate limit changed nothing on the server; every other
/// failure means the shown result may be out of date.
bool teacherTopicResultActionFailureReloads(ApiFailure failure) {
  final code = failure.serverCode;
  return code != ApiErrorCodes.validationFailed &&
      code != ApiErrorCodes.rateLimited;
}

String teacherTopicResultBulkReport(
  TeacherTopicResultBulkAction action,
  TeacherTopicResultBulkOutcome outcome,
) {
  final processed = outcome.processed;
  final done = switch (action) {
    TeacherTopicResultBulkAction.releaseToStudents =>
      'Released to $processed ${_students(processed)}.',
    TeacherTopicResultBulkAction.releaseToParents =>
      'Released to the Parents of $processed ${_students(processed)}.',
    TeacherTopicResultBulkAction.close =>
      'Closed $processed ${processed == 1 ? 'result' : 'results'}.',
  };
  if (!outcome.skippedAny) {
    return done;
  }
  final alreadyDone = action == TeacherTopicResultBulkAction.close
      ? 'already closed'
      : 'already released';
  final skipped = [
    if (outcome.alreadyDone > 0) '${outcome.alreadyDone} $alreadyDone',
    if (outcome.notReady > 0) '${outcome.notReady} not ready yet',
  ];
  return '$done Skipped: ${skipped.join(', ')}.';
}

String _students(int count) => count == 1 ? 'Student' : 'Students';
