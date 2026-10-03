import '../../../core/network/api_failure.dart';
import '../domain/student_topic_result.dart';

enum StudentTopicResultLoadStatus { initial, loading, data, refreshing, error }

/// The Student's Topic result section. Once a response is [loaded], [result]
/// is authoritative: null then means the Student has no Topic result here.
class StudentTopicResultState {
  const StudentTopicResultState({
    this.status = StudentTopicResultLoadStatus.initial,
    this.loaded = false,
    this.result,
    this.failure,
  });

  final StudentTopicResultLoadStatus status;
  final bool loaded;
  final StudentTopicResult? result;
  final ApiFailure? failure;

  bool get isLoading =>
      status == StudentTopicResultLoadStatus.loading ||
      status == StudentTopicResultLoadStatus.refreshing;
}
