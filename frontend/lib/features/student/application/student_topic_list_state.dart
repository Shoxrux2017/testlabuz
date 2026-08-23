import '../../../core/network/api_failure.dart';
import '../domain/student_topic_list.dart';
import '../domain/student_topic_list_query.dart';

enum StudentTopicListStatus {
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

class StudentTopicListState {
  const StudentTopicListState._({
    required this.status,
    required this.query,
    required this.searchDraft,
    required this.result,
    required this.failure,
    required this.searchErrorText,
    required this.isRetryInFlight,
  });

  const StudentTopicListState.initial()
    : this._(
        status: StudentTopicListStatus.initial,
        query: const StudentTopicListQuery.initial(),
        searchDraft: '',
        result: null,
        failure: null,
        searchErrorText: null,
        isRetryInFlight: false,
      );

  const StudentTopicListState.loading({
    required StudentTopicListQuery query,
    required String searchDraft,
  }) : this._(
         status: StudentTopicListStatus.loading,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
       );

  const StudentTopicListState.queryLoading({
    required StudentTopicListQuery query,
    required String searchDraft,
  }) : this._(
         status: StudentTopicListStatus.queryLoading,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
       );

  const StudentTopicListState.refreshing({
    required StudentTopicListQuery query,
    required String searchDraft,
    required StudentTopicListPage result,
  }) : this._(
         status: StudentTopicListStatus.refreshing,
         query: query,
         searchDraft: searchDraft,
         result: result,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
       );

  factory StudentTopicListState.fromResult({
    required StudentTopicListQuery query,
    required String searchDraft,
    required StudentTopicListPage result,
  }) {
    final status = switch ((
      result.topics.isNotEmpty,
      result.pagination.total,
    )) {
      (true, _) => StudentTopicListStatus.data,
      (false, 0) when query.hasFilters => StudentTopicListStatus.filteredEmpty,
      (false, 0) => StudentTopicListStatus.globalEmpty,
      (false, _) => StudentTopicListStatus.emptyPage,
    };

    return StudentTopicListState._(
      status: status,
      query: query,
      searchDraft: searchDraft,
      result: result,
      failure: null,
      searchErrorText: StudentTopicListQuery.isSearchInputValid(searchDraft)
          ? null
          : 'Search must be 254 characters or fewer.',
      isRetryInFlight: false,
    );
  }

  const StudentTopicListState.error({
    required StudentTopicListQuery query,
    required String searchDraft,
    required ApiFailure failure,
    bool isRetryInFlight = false,
    String? searchErrorText,
  }) : this._(
         status: StudentTopicListStatus.error,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: failure,
         searchErrorText: searchErrorText,
         isRetryInFlight: isRetryInFlight,
       );

  final StudentTopicListStatus status;
  final StudentTopicListQuery query;
  final String searchDraft;
  final StudentTopicListPage? result;
  final ApiFailure? failure;
  final String? searchErrorText;
  final bool isRetryInFlight;

  bool get isRequestInFlight =>
      status == StudentTopicListStatus.loading ||
      status == StudentTopicListStatus.queryLoading ||
      status == StudentTopicListStatus.refreshing ||
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
      query.page != StudentTopicListQuery.initialPage;

  StudentTopicListState withSearchDraft(String value, {String? errorText}) {
    return StudentTopicListState._(
      status: status,
      query: query,
      searchDraft: value,
      result: result,
      failure: failure,
      searchErrorText: errorText,
      isRetryInFlight: isRetryInFlight,
    );
  }

  StudentTopicListState retrying() {
    final currentFailure = failure;
    if (status != StudentTopicListStatus.error || currentFailure == null) {
      return this;
    }

    return StudentTopicListState.error(
      query: query,
      searchDraft: searchDraft,
      failure: currentFailure,
      isRetryInFlight: true,
      searchErrorText: searchErrorText,
    );
  }
}
