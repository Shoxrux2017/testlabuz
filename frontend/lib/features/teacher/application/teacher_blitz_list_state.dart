import '../../../core/network/api_failure.dart';
import '../domain/teacher_blitz_list.dart';
import '../domain/teacher_blitz_list_query.dart';

enum TeacherBlitzListStatus { initial, loading, data, refreshing, error }

class TeacherBlitzListState {
  const TeacherBlitzListState({
    this.status = TeacherBlitzListStatus.initial,
    this.query = const TeacherBlitzListQuery.initial(),
    this.result,
    this.failure,
    this.isStale = false,
  });

  final TeacherBlitzListStatus status;
  final TeacherBlitzListQuery query;
  final TeacherBlitzList? result;
  final ApiFailure? failure;

  /// True only when [result] is retained after a failed refresh.
  final bool isStale;

  bool get isRequestInFlight =>
      status == TeacherBlitzListStatus.loading ||
      status == TeacherBlitzListStatus.refreshing;

  bool get canGoPrevious =>
      !isRequestInFlight &&
      status == TeacherBlitzListStatus.data &&
      query.page > 1;

  bool get canGoNext {
    final pagination = result?.pagination;

    return !isRequestInFlight &&
        status == TeacherBlitzListStatus.data &&
        pagination != null &&
        pagination.page < pagination.lastPage;
  }
}
