import '../../../core/network/api_failure.dart';
import '../domain/student_topic.dart';

enum StudentTopicDetailStatus {
  initial,
  loading,
  data,
  refreshing,
  notFound,
  error,
}

class StudentTopicDetailState {
  const StudentTopicDetailState({
    this.status = StudentTopicDetailStatus.initial,
    this.topic,
    this.failure,
  });

  final StudentTopicDetailStatus status;
  final StudentTopicDetail? topic;
  final ApiFailure? failure;

  bool get isLoading =>
      status == StudentTopicDetailStatus.loading ||
      status == StudentTopicDetailStatus.refreshing;
}
