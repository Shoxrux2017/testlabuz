import '../../../core/network/api_failure.dart';
import '../domain/teacher_submission_list.dart';
import '../domain/teacher_submission_list_query.dart';

enum TeacherReviewQueueStatus { initial, loading, data, refreshing, error }

class TeacherReviewQueueState {
  const TeacherReviewQueueState({
    this.status = TeacherReviewQueueStatus.initial,
    this.query = const TeacherSubmissionListQuery.initial(),
    this.result,
    this.failure,
    this.isStale = false,
  });

  final TeacherReviewQueueStatus status;
  final TeacherSubmissionListQuery query;
  final TeacherSubmissionList? result;
  final ApiFailure? failure;

  /// True only when [result] is retained after a failed refresh.
  final bool isStale;

  bool get isRequestInFlight =>
      status == TeacherReviewQueueStatus.loading ||
      status == TeacherReviewQueueStatus.refreshing;

  bool get canGoPrevious =>
      !isRequestInFlight &&
      status == TeacherReviewQueueStatus.data &&
      query.page > TeacherSubmissionListQuery.initialPage;

  bool get canGoNext {
    final pagination = result?.pagination;
    return !isRequestInFlight &&
        status == TeacherReviewQueueStatus.data &&
        pagination != null &&
        query.page < pagination.lastPage;
  }
}
