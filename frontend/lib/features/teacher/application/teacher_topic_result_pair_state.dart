import '../../../core/network/api_failure.dart';
import '../domain/teacher_topic_result_pair.dart';

enum TeacherTopicResultPairStatus { initial, loading, data, refreshing, error }

class TeacherTopicResultPairState {
  const TeacherTopicResultPairState({
    this.status = TeacherTopicResultPairStatus.initial,
    this.pair,
    this.failure,
    this.isStale = false,
  });

  final TeacherTopicResultPairStatus status;
  final TeacherTopicResultPair? pair;
  final ApiFailure? failure;

  /// True when a failed refresh retained the previously confirmed value.
  final bool isStale;

  bool get hasConfirmedData => status == TeacherTopicResultPairStatus.data;
  bool get isRequestInFlight =>
      status == TeacherTopicResultPairStatus.loading ||
      status == TeacherTopicResultPairStatus.refreshing;
}
