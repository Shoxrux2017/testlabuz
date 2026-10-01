import '../../../core/network/api_failure.dart';
import '../domain/teacher_submission_detail.dart';

enum TeacherSubmissionDetailStatus {
  initial,
  loading,
  data,
  refreshing,
  notFound,
  error,
}

class TeacherSubmissionDetailState {
  const TeacherSubmissionDetailState({
    this.status = TeacherSubmissionDetailStatus.initial,
    this.detail,
    this.failure,
    this.isStale = false,
  });

  final TeacherSubmissionDetailStatus status;
  final TeacherSubmissionDetail? detail;
  final ApiFailure? failure;

  /// True only when [detail] is retained after a failed refresh.
  final bool isStale;

  bool get isLoading =>
      status == TeacherSubmissionDetailStatus.loading ||
      status == TeacherSubmissionDetailStatus.refreshing;
}
