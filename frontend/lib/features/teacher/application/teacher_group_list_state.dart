import '../../../core/network/api_failure.dart';
import '../domain/teacher_group_list.dart';
import '../domain/teacher_group_list_query.dart';

enum TeacherGroupListStatus {
  initial,
  loading,
  queryLoading,
  refreshing,
  data,
  globalEmpty,
  filteredEmpty,
  emptyPage,
  error,
}

class TeacherGroupListState {
  const TeacherGroupListState._({
    required this.status,
    required this.query,
    required this.searchDraft,
    required this.result,
    required this.failure,
    required this.searchErrorText,
    required this.isRetryInFlight,
  });

  const TeacherGroupListState.initial()
    : this._(
        status: TeacherGroupListStatus.initial,
        query: const TeacherGroupListQuery.initial(),
        searchDraft: '',
        result: null,
        failure: null,
        searchErrorText: null,
        isRetryInFlight: false,
      );

  const TeacherGroupListState.loading({
    required TeacherGroupListQuery query,
    required String searchDraft,
  }) : this._(
         status: TeacherGroupListStatus.loading,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
       );

  const TeacherGroupListState.queryLoading({
    required TeacherGroupListQuery query,
    required String searchDraft,
  }) : this._(
         status: TeacherGroupListStatus.queryLoading,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
       );

  const TeacherGroupListState.refreshing({
    required TeacherGroupListQuery query,
    required String searchDraft,
    required TeacherGroupListPage result,
  }) : this._(
         status: TeacherGroupListStatus.refreshing,
         query: query,
         searchDraft: searchDraft,
         result: result,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
       );

  factory TeacherGroupListState.fromResult({
    required TeacherGroupListQuery query,
    required String searchDraft,
    required TeacherGroupListPage result,
  }) {
    final status = switch ((
      result.groups.isNotEmpty,
      result.pagination.total,
    )) {
      (true, _) => TeacherGroupListStatus.data,
      (false, 0) when query.hasSearch => TeacherGroupListStatus.filteredEmpty,
      (false, 0) => TeacherGroupListStatus.globalEmpty,
      (false, _) => TeacherGroupListStatus.emptyPage,
    };

    return TeacherGroupListState._(
      status: status,
      query: query,
      searchDraft: searchDraft,
      result: result,
      failure: null,
      searchErrorText: TeacherGroupListQuery.isSearchInputValid(searchDraft)
          ? null
          : 'Search must be 254 characters or fewer.',
      isRetryInFlight: false,
    );
  }

  const TeacherGroupListState.error({
    required TeacherGroupListQuery query,
    required String searchDraft,
    required ApiFailure failure,
    bool isRetryInFlight = false,
    String? searchErrorText,
  }) : this._(
         status: TeacherGroupListStatus.error,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: failure,
         searchErrorText: searchErrorText,
         isRetryInFlight: isRetryInFlight,
       );

  final TeacherGroupListStatus status;
  final TeacherGroupListQuery query;
  final String searchDraft;
  final TeacherGroupListPage? result;
  final ApiFailure? failure;
  final String? searchErrorText;
  final bool isRetryInFlight;

  bool get isRequestInFlight =>
      status == TeacherGroupListStatus.loading ||
      status == TeacherGroupListStatus.queryLoading ||
      status == TeacherGroupListStatus.refreshing ||
      isRetryInFlight;

  bool get canGoPrevious =>
      !isRequestInFlight &&
      searchErrorText == null &&
      (result?.pagination.page ?? query.page) > 1;

  bool get canGoNext {
    if (isRequestInFlight || searchErrorText != null) {
      return false;
    }
    final pagination = result?.pagination;

    return pagination != null &&
        result!.groups.isNotEmpty &&
        pagination.page < pagination.lastPage;
  }

  bool get canClearSearch =>
      searchDraft.isNotEmpty || searchErrorText != null || query.search != null;

  TeacherGroupListState withSearchDraft(String value, {String? errorText}) {
    return TeacherGroupListState._(
      status: status,
      query: query,
      searchDraft: value,
      result: result,
      failure: failure,
      searchErrorText: errorText,
      isRetryInFlight: isRetryInFlight,
    );
  }

  TeacherGroupListState retrying() {
    final currentFailure = failure;
    if (status != TeacherGroupListStatus.error || currentFailure == null) {
      return this;
    }

    return TeacherGroupListState.error(
      query: query,
      searchDraft: searchDraft,
      failure: currentFailure,
      isRetryInFlight: true,
      searchErrorText: searchErrorText,
    );
  }
}
