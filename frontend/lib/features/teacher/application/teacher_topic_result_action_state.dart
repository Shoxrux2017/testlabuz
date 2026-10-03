/// The state of the single-Student result actions (docs/09 §§25.7-25.8,
/// 27.3-27.4).
enum TeacherTopicResultActionStatus { idle, submitting }

class TeacherTopicResultActionState {
  const TeacherTopicResultActionState({
    this.status = TeacherTopicResultActionStatus.idle,
    this.feedback,
    this.notice,
  });

  final TeacherTopicResultActionStatus status;

  /// One-shot confirmed success text for a SnackBar.
  final String? feedback;

  /// The persistent failure or reload explanation of the last action.
  final String? notice;

  bool get isBusy => status == TeacherTopicResultActionStatus.submitting;

  TeacherTopicResultActionState withoutFeedback() {
    return TeacherTopicResultActionState(status: status, notice: notice);
  }
}
