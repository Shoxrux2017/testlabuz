/// How many submissions of a task wait for the Teacher's review, and how many of
/// those are past the Homework review deadline (always 0 for Blitz).
class TeacherReviewSummary {
  const TeacherReviewSummary({
    required this.waitingForTeacherReview,
    required this.overdue,
  });

  final int waitingForTeacherReview;
  final int overdue;
}
