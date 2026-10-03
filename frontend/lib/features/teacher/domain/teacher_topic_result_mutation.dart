/// The most comment characters after trimming, counted as Unicode code points
/// as the server counts them (docs/09 §25.7).
const teacherTopicResultCommentMaxLength = 2000;

/// Who a Teacher release opens a Topic result to (docs/09 §§27.3-27.5).
enum TeacherTopicResultAudience {
  student('student'),
  parent('parent');

  const TeacherTopicResultAudience(this.segment);

  final String segment;
}

/// The counts of a bulk release or close (docs/09 §25.9).
class TeacherTopicResultBulkOutcome {
  const TeacherTopicResultBulkOutcome({
    required this.processed,
    required this.alreadyDone,
    required this.notReady,
  });

  final int processed;
  final int alreadyDone;
  final int notReady;

  bool get skippedAny => alreadyDone > 0 || notReady > 0;
}

/// A result action whose server outcome is not confirmed; the caller reloads
/// instead of assuming success or failure.
class TeacherTopicResultMutationOutcomeUnknownException implements Exception {
  const TeacherTopicResultMutationOutcomeUnknownException();
}
