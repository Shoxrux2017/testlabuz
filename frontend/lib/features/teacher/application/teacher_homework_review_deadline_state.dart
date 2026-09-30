enum TeacherHomeworkReviewDeadlineStatus {
  idle,
  submitting,
  reconciling,
  definiteFailure,
  outcomeReview,
  confirmedSuccess,
}

class TeacherHomeworkReviewDeadlineState {
  const TeacherHomeworkReviewDeadlineState({
    this.status = TeacherHomeworkReviewDeadlineStatus.idle,
    this.feedback,
    this.conflictCode,
    this.requiresCurrentCheck = false,
  });

  final TeacherHomeworkReviewDeadlineStatus status;
  final String? feedback;

  /// The server code of a definite failure.
  final String? conflictCode;
  final bool requiresCurrentCheck;

  bool get isBusy =>
      status == TeacherHomeworkReviewDeadlineStatus.submitting ||
      status == TeacherHomeworkReviewDeadlineStatus.reconciling;

  bool get canCheckCurrent =>
      status == TeacherHomeworkReviewDeadlineStatus.outcomeReview &&
      requiresCurrentCheck;
}
