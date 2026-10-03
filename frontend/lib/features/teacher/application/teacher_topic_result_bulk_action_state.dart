/// The bulk result actions over a Topic's whole cohort (docs/09 §§25.9, 27.5).
enum TeacherTopicResultBulkAction { releaseToStudents, releaseToParents, close }

enum TeacherTopicResultBulkActionStatus { idle, submitting }

class TeacherTopicResultBulkActionState {
  const TeacherTopicResultBulkActionState({
    this.status = TeacherTopicResultBulkActionStatus.idle,
    this.report,
    this.notice,
  });

  final TeacherTopicResultBulkActionStatus status;

  /// What the last confirmed bulk action processed and skipped.
  final String? report;

  /// The failure or reload explanation of the last bulk action.
  final String? notice;

  bool get isBusy => status == TeacherTopicResultBulkActionStatus.submitting;
}
