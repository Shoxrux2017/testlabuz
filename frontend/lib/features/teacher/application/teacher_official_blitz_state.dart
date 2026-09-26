enum TeacherOfficialBlitzStatus {
  idle,
  submitting,
  reconciling,
  confirmedSuccess,
  definiteFailure,
  outcomeReview,
}

/// Official-designation operation status; the Topic result-pair controller
/// stays the authority for which Blitz is official.
class TeacherOfficialBlitzState {
  const TeacherOfficialBlitzState({
    this.status = TeacherOfficialBlitzStatus.idle,
    this.feedback,
    this.notice,
    this.conflictCode,
    this.requiresCurrentCheck = false,
  });

  final TeacherOfficialBlitzStatus status;

  /// One-shot route feedback, used for confirmed success.
  final String? feedback;

  /// Persistent safe review/failure text next to the official controls.
  final String? notice;
  final String? conflictCode;

  /// The pair could not be read, so the route stays blocked until checked.
  final bool requiresCurrentCheck;

  bool get isBusy =>
      status == TeacherOfficialBlitzStatus.submitting ||
      status == TeacherOfficialBlitzStatus.reconciling;

  bool get canCheckCurrent =>
      status == TeacherOfficialBlitzStatus.outcomeReview;

  bool get hasBlockingOutcome => canCheckCurrent && requiresCurrentCheck;

  TeacherOfficialBlitzState withoutFeedback() {
    return TeacherOfficialBlitzState(
      status: status,
      notice: notice,
      conflictCode: conflictCode,
      requiresCurrentCheck: requiresCurrentCheck,
    );
  }
}
