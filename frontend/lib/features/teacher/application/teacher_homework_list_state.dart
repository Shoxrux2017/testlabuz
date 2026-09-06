import '../../../core/network/api_failure.dart';
import '../domain/teacher_homework_list.dart';
import '../domain/teacher_homework_list_query.dart';

enum TeacherHomeworkListStatus { initial, loading, data, refreshing, error }

class TeacherHomeworkListState {
  const TeacherHomeworkListState({
    this.status = TeacherHomeworkListStatus.initial,
    this.query = const TeacherHomeworkListQuery.initial(),
    this.searchDraft = '',
    this.result,
    this.failure,
    this.searchErrorText,
    this.isStale = false,
  });

  final TeacherHomeworkListStatus status;
  final TeacherHomeworkListQuery query;
  final String searchDraft;
  final TeacherHomeworkList? result;
  final ApiFailure? failure;
  final String? searchErrorText;

  /// True only when [result] is retained after a failed refresh.
  final bool isStale;

  bool get isRequestInFlight =>
      status == TeacherHomeworkListStatus.loading ||
      status == TeacherHomeworkListStatus.refreshing;

  bool get hasActiveFilters =>
      query.search != null ||
      query.status != null ||
      query.assignmentMode != null;

  bool get canGoPrevious =>
      !isRequestInFlight &&
      status == TeacherHomeworkListStatus.data &&
      query.page > 1;

  bool get canGoNext {
    final pagination = result?.pagination;

    return !isRequestInFlight &&
        status == TeacherHomeworkListStatus.data &&
        pagination != null &&
        pagination.page < pagination.lastPage;
  }

  TeacherHomeworkListState withSearchDraft(String value, {String? errorText}) {
    return TeacherHomeworkListState(
      status: status,
      query: query,
      searchDraft: value,
      result: result,
      failure: failure,
      searchErrorText: errorText,
      isStale: isStale,
    );
  }
}
