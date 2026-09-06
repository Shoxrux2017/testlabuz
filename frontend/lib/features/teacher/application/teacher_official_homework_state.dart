enum TeacherOfficialHomeworkStatus {
  idle,
  submitting,
  reconciling,
  confirmedSuccess,
  definiteFailure,
  outcomeReview,
  unavailable,
}

class TeacherOfficialHomeworkState {
  const TeacherOfficialHomeworkState({
    this.status = TeacherOfficialHomeworkStatus.idle,
    this.requestedHomeworkId,
    this.feedback,
    this.conflictCode,
    this.requiresCurrentCheck = false,
  });

  final TeacherOfficialHomeworkStatus status;
  final String? requestedHomeworkId;
  final String? feedback;
  final String? conflictCode;
  final bool requiresCurrentCheck;

  bool get isBusy =>
      status == TeacherOfficialHomeworkStatus.submitting ||
      status == TeacherOfficialHomeworkStatus.reconciling;

  bool get canCheckCurrent =>
      status == TeacherOfficialHomeworkStatus.outcomeReview &&
      requestedHomeworkId != null &&
      requiresCurrentCheck;
}
