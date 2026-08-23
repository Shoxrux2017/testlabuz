import '../../../core/network/api_failure.dart';
import '../domain/teacher_topic.dart';

enum TeacherTopicDetailStatus {
  initial,
  loading,
  data,
  refreshing,
  notFound,
  error,
}

class TeacherTopicDetailState {
  const TeacherTopicDetailState({
    this.status = TeacherTopicDetailStatus.initial,
    this.topic,
    this.failure,
  });

  final TeacherTopicDetailStatus status;
  final TeacherTopic? topic;
  final ApiFailure? failure;

  bool get isLoading =>
      status == TeacherTopicDetailStatus.loading ||
      status == TeacherTopicDetailStatus.refreshing;
}
