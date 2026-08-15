import '../../../core/network/api_failure.dart';
import '../domain/institution_user_list.dart';
import '../domain/institution_user_list_query.dart';

enum InstitutionUserListStatus {
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

class InstitutionUserListState {
  const InstitutionUserListState._({
    required this.status,
    required this.query,
    required this.searchDraft,
    required this.result,
    required this.failure,
    required this.searchErrorText,
    required this.isRetryInFlight,
  });

  const InstitutionUserListState.initial()
    : this._(
        status: InstitutionUserListStatus.initial,
        query: const InstitutionUserListQuery.initial(),
        searchDraft: '',
        result: null,
        failure: null,
        searchErrorText: null,
        isRetryInFlight: false,
      );

  const InstitutionUserListState.loading({
    required InstitutionUserListQuery query,
    required String searchDraft,
  }) : this._(
         status: InstitutionUserListStatus.loading,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
       );

  const InstitutionUserListState.queryLoading({
    required InstitutionUserListQuery query,
    required String searchDraft,
  }) : this._(
         status: InstitutionUserListStatus.queryLoading,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
       );

  const InstitutionUserListState.refreshing({
    required InstitutionUserListQuery query,
    required String searchDraft,
    required InstitutionUserListPage result,
  }) : this._(
         status: InstitutionUserListStatus.refreshing,
         query: query,
         searchDraft: searchDraft,
         result: result,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
       );

  factory InstitutionUserListState.fromResult({
    required InstitutionUserListQuery query,
    required String searchDraft,
    required InstitutionUserListPage result,
  }) {
    final status = switch ((result.users.isNotEmpty, result.pagination.total)) {
      (true, _) => InstitutionUserListStatus.data,
      (false, 0) when query.hasSearchOrFilter =>
        InstitutionUserListStatus.filteredEmpty,
      (false, 0) => InstitutionUserListStatus.globalEmpty,
      (false, _) => InstitutionUserListStatus.emptyPage,
    };

    return InstitutionUserListState._(
      status: status,
      query: query,
      searchDraft: searchDraft,
      result: result,
      failure: null,
      searchErrorText: null,
      isRetryInFlight: false,
    );
  }

  const InstitutionUserListState.error({
    required InstitutionUserListQuery query,
    required String searchDraft,
    required ApiFailure failure,
    bool isRetryInFlight = false,
  }) : this._(
         status: InstitutionUserListStatus.error,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: failure,
         searchErrorText: null,
         isRetryInFlight: isRetryInFlight,
       );

  final InstitutionUserListStatus status;
  final InstitutionUserListQuery query;
  final String searchDraft;
  final InstitutionUserListPage? result;
  final ApiFailure? failure;
  final String? searchErrorText;
  final bool isRetryInFlight;

  bool get hasRows => result?.users.isNotEmpty ?? false;

  bool get isRequestInFlight =>
      status == InstitutionUserListStatus.loading ||
      status == InstitutionUserListStatus.queryLoading ||
      status == InstitutionUserListStatus.refreshing ||
      isRetryInFlight;

  bool get canChangeQuery => !isRequestInFlight && searchErrorText == null;

  bool get canGoPrevious {
    if (!canChangeQuery) {
      return false;
    }

    return (result?.pagination.page ?? query.page) > 1;
  }

  bool get canGoNext {
    if (!canChangeQuery || !hasRows) {
      return false;
    }

    final pagination = result?.pagination;

    return pagination != null && pagination.page < pagination.lastPage;
  }

  bool get canClearFilters {
    return searchDraft.isNotEmpty ||
        searchErrorText != null ||
        query.search != null ||
        query.role != null ||
        query.status != null ||
        query.page != InstitutionUserListQuery.initialPage;
  }

  InstitutionUserListState withSearchDraft(String value, {String? errorText}) {
    return InstitutionUserListState._(
      status: status,
      query: query,
      searchDraft: value,
      result: result,
      failure: failure,
      searchErrorText: errorText,
      isRetryInFlight: isRetryInFlight,
    );
  }

  InstitutionUserListState retrying({required String searchDraft}) {
    final currentFailure = failure;
    if (status != InstitutionUserListStatus.error || currentFailure == null) {
      return this;
    }

    return InstitutionUserListState.error(
      query: query,
      searchDraft: searchDraft,
      failure: currentFailure,
      isRetryInFlight: true,
    );
  }
}
