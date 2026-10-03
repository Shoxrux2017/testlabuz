import '../../../core/network/api_failure.dart';
import '../domain/teacher_topic_result_list.dart';

enum TeacherTopicResultListStatus { initial, loading, data, refreshing, error }

class TeacherTopicResultListState {
  const TeacherTopicResultListState({
    this.status = TeacherTopicResultListStatus.initial,
    this.query = const TeacherTopicResultListQuery(),
    this.result,
    this.counts,
    this.failure,
    this.isStale = false,
  });

  final TeacherTopicResultListStatus status;
  final TeacherTopicResultListQuery query;
  final TeacherTopicResultList? result;

  /// The last confirmed cohort counts. They do not depend on the filters, so
  /// they stay while another page or filter loads or fails.
  final TeacherTopicResultCounts? counts;
  final ApiFailure? failure;

  /// True only when [result] is retained after a failed refresh.
  final bool isStale;

  bool get isRequestInFlight =>
      status == TeacherTopicResultListStatus.loading ||
      status == TeacherTopicResultListStatus.refreshing;

  bool get canGoPrevious =>
      !isRequestInFlight &&
      status == TeacherTopicResultListStatus.data &&
      query.page > TeacherTopicResultListQuery.initialPage;

  bool get canGoNext {
    final pagination = result?.pagination;
    return !isRequestInFlight &&
        status == TeacherTopicResultListStatus.data &&
        pagination != null &&
        query.page < pagination.lastPage;
  }
}
