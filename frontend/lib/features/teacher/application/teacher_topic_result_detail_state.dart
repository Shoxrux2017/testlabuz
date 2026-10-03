import '../../../core/network/api_failure.dart';
import '../domain/teacher_topic_result.dart';

enum TeacherTopicResultDetailStatus {
  initial,
  loading,
  data,
  refreshing,
  error,
}

class TeacherTopicResultDetailState {
  const TeacherTopicResultDetailState({
    this.status = TeacherTopicResultDetailStatus.initial,
    this.detail,
    this.failure,
    this.isStale = false,
  });

  final TeacherTopicResultDetailStatus status;
  final TeacherTopicResultDetail? detail;
  final ApiFailure? failure;

  /// True only when [detail] is retained after a failed refresh.
  final bool isStale;

  bool get isRequestInFlight =>
      status == TeacherTopicResultDetailStatus.loading ||
      status == TeacherTopicResultDetailStatus.refreshing;
}
