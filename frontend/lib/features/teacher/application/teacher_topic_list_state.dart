import '../../../core/network/api_failure.dart';
import '../domain/teacher_group.dart';
import '../domain/teacher_topic_list.dart';
import '../domain/teacher_topic_list_query.dart';

enum TeacherTopicListStatus {
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

class TeacherTopicListState {
  const TeacherTopicListState._({
    required this.status,
    required this.query,
    required this.searchDraft,
    required this.selectedGroup,
    required this.result,
    required this.failure,
    required this.searchErrorText,
    required this.isRetryInFlight,
    required this.notice,
  });

  const TeacherTopicListState.initial()
    : this._(
        status: TeacherTopicListStatus.initial,
        query: const TeacherTopicListQuery.initial(),
        searchDraft: '',
        selectedGroup: null,
        result: null,
        failure: null,
        searchErrorText: null,
        isRetryInFlight: false,
        notice: null,
      );

  const TeacherTopicListState.loading({
    required TeacherTopicListQuery query,
    required String searchDraft,
    required TeacherGroupSummary? selectedGroup,
  }) : this._(
         status: TeacherTopicListStatus.loading,
         query: query,
         searchDraft: searchDraft,
         selectedGroup: selectedGroup,
         result: null,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
         notice: null,
       );

  const TeacherTopicListState.queryLoading({
    required TeacherTopicListQuery query,
    required String searchDraft,
    required TeacherGroupSummary? selectedGroup,
    String? notice,
  }) : this._(
         status: TeacherTopicListStatus.queryLoading,
         query: query,
         searchDraft: searchDraft,
         selectedGroup: selectedGroup,
         result: null,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
         notice: notice,
       );

  const TeacherTopicListState.refreshing({
    required TeacherTopicListQuery query,
    required String searchDraft,
    required TeacherGroupSummary? selectedGroup,
    required TeacherTopicListPage result,
  }) : this._(
         status: TeacherTopicListStatus.refreshing,
         query: query,
         searchDraft: searchDraft,
         selectedGroup: selectedGroup,
         result: result,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
         notice: null,
       );

  factory TeacherTopicListState.fromResult({
    required TeacherTopicListQuery query,
    required String searchDraft,
    required TeacherGroupSummary? selectedGroup,
    required TeacherTopicListPage result,
    String? notice,
  }) {
    final status = switch ((
      result.topics.isNotEmpty,
      result.pagination.total,
    )) {
      (true, _) => TeacherTopicListStatus.data,
      (false, 0) when query.hasFilters => TeacherTopicListStatus.filteredEmpty,
      (false, 0) => TeacherTopicListStatus.globalEmpty,
      (false, _) => TeacherTopicListStatus.emptyPage,
    };

    return TeacherTopicListState._(
      status: status,
      query: query,
      searchDraft: searchDraft,
      selectedGroup: selectedGroup,
      result: result,
      failure: null,
      searchErrorText: TeacherTopicListQuery.isSearchInputValid(searchDraft)
          ? null
          : 'Search must be 254 characters or fewer.',
      isRetryInFlight: false,
      notice: notice,
    );
  }

  const TeacherTopicListState.error({
    required TeacherTopicListQuery query,
    required String searchDraft,
    required TeacherGroupSummary? selectedGroup,
    required ApiFailure failure,
    bool isRetryInFlight = false,
    String? notice,
    String? searchErrorText,
  }) : this._(
         status: TeacherTopicListStatus.error,
         query: query,
         searchDraft: searchDraft,
         selectedGroup: selectedGroup,
         result: null,
         failure: failure,
         searchErrorText: searchErrorText,
         isRetryInFlight: isRetryInFlight,
         notice: notice,
       );

  final TeacherTopicListStatus status;
  final TeacherTopicListQuery query;
  final String searchDraft;
  final TeacherGroupSummary? selectedGroup;
  final TeacherTopicListPage? result;
  final ApiFailure? failure;
  final String? searchErrorText;
  final bool isRetryInFlight;
  final String? notice;

  bool get isRequestInFlight =>
      status == TeacherTopicListStatus.loading ||
      status == TeacherTopicListStatus.queryLoading ||
      status == TeacherTopicListStatus.refreshing ||
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
        result!.topics.isNotEmpty &&
        pagination.page < pagination.lastPage;
  }

  bool get canClearFilters =>
      searchDraft.isNotEmpty ||
      searchErrorText != null ||
      query.hasFilters ||
      query.page != TeacherTopicListQuery.initialPage;

  TeacherTopicListState withSearchDraft(String value, {String? errorText}) {
    return TeacherTopicListState._(
      status: status,
      query: query,
      searchDraft: value,
      selectedGroup: selectedGroup,
      result: result,
      failure: failure,
      searchErrorText: errorText,
      isRetryInFlight: isRetryInFlight,
      notice: notice,
    );
  }

  TeacherTopicListState withoutNotice() {
    if (notice == null) {
      return this;
    }

    return TeacherTopicListState._(
      status: status,
      query: query,
      searchDraft: searchDraft,
      selectedGroup: selectedGroup,
      result: result,
      failure: failure,
      searchErrorText: searchErrorText,
      isRetryInFlight: isRetryInFlight,
      notice: null,
    );
  }

  TeacherTopicListState retrying() {
    final currentFailure = failure;
    if (status != TeacherTopicListStatus.error || currentFailure == null) {
      return this;
    }

    return TeacherTopicListState.error(
      query: query,
      searchDraft: searchDraft,
      selectedGroup: selectedGroup,
      failure: currentFailure,
      isRetryInFlight: true,
      notice: notice,
      searchErrorText: searchErrorText,
    );
  }
}
