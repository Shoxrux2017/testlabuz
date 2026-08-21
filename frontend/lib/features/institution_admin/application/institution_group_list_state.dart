import '../../../core/network/api_failure.dart';
import '../domain/institution_group_list.dart';
import '../domain/institution_group_list_query.dart';

enum InstitutionGroupListStatus {
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

class InstitutionGroupListState {
  const InstitutionGroupListState._({
    required this.status,
    required this.query,
    required this.searchDraft,
    required this.result,
    required this.failure,
    required this.searchErrorText,
    required this.isRetryInFlight,
    required this.recoveryWarning,
  });

  const InstitutionGroupListState.initial()
    : this._(
        status: InstitutionGroupListStatus.initial,
        query: const InstitutionGroupListQuery.initial(),
        searchDraft: '',
        result: null,
        failure: null,
        searchErrorText: null,
        isRetryInFlight: false,
        recoveryWarning: null,
      );

  const InstitutionGroupListState.loading({
    required InstitutionGroupListQuery query,
    required String searchDraft,
    String? recoveryWarning,
  }) : this._(
         status: InstitutionGroupListStatus.loading,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
         recoveryWarning: recoveryWarning,
       );

  const InstitutionGroupListState.queryLoading({
    required InstitutionGroupListQuery query,
    required String searchDraft,
    String? recoveryWarning,
  }) : this._(
         status: InstitutionGroupListStatus.queryLoading,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
         recoveryWarning: recoveryWarning,
       );

  const InstitutionGroupListState.refreshing({
    required InstitutionGroupListQuery query,
    required String searchDraft,
    required InstitutionGroupListPage result,
    String? recoveryWarning,
  }) : this._(
         status: InstitutionGroupListStatus.refreshing,
         query: query,
         searchDraft: searchDraft,
         result: result,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
         recoveryWarning: recoveryWarning,
       );

  factory InstitutionGroupListState.fromResult({
    required InstitutionGroupListQuery query,
    required String searchDraft,
    required InstitutionGroupListPage result,
    String? recoveryWarning,
  }) {
    final status = switch ((
      result.groups.isNotEmpty,
      result.pagination.total,
    )) {
      (true, _) => InstitutionGroupListStatus.data,
      (false, 0) when query.hasSearchOrFilter =>
        InstitutionGroupListStatus.filteredEmpty,
      (false, 0) => InstitutionGroupListStatus.globalEmpty,
      (false, _) => InstitutionGroupListStatus.emptyPage,
    };

    return InstitutionGroupListState._(
      status: status,
      query: query,
      searchDraft: searchDraft,
      result: result,
      failure: null,
      searchErrorText: null,
      isRetryInFlight: false,
      recoveryWarning: recoveryWarning,
    );
  }

  const InstitutionGroupListState.error({
    required InstitutionGroupListQuery query,
    required String searchDraft,
    required ApiFailure failure,
    bool isRetryInFlight = false,
    String? recoveryWarning,
  }) : this._(
         status: InstitutionGroupListStatus.error,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: failure,
         searchErrorText: null,
         isRetryInFlight: isRetryInFlight,
         recoveryWarning: recoveryWarning,
       );

  final InstitutionGroupListStatus status;
  final InstitutionGroupListQuery query;
  final String searchDraft;
  final InstitutionGroupListPage? result;
  final ApiFailure? failure;
  final String? searchErrorText;
  final bool isRetryInFlight;
  final String? recoveryWarning;

  bool get hasRows => result?.groups.isNotEmpty ?? false;

  bool get isRequestInFlight =>
      status == InstitutionGroupListStatus.loading ||
      status == InstitutionGroupListStatus.queryLoading ||
      status == InstitutionGroupListStatus.refreshing ||
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
        query.status != null ||
        query.page != InstitutionGroupListQuery.initialPage;
  }

  InstitutionGroupListState withSearchDraft(String value, {String? errorText}) {
    return InstitutionGroupListState._(
      status: status,
      query: query,
      searchDraft: value,
      result: result,
      failure: failure,
      searchErrorText: errorText,
      isRetryInFlight: isRetryInFlight,
      recoveryWarning: recoveryWarning,
    );
  }

  InstitutionGroupListState retrying() {
    final currentFailure = failure;
    if (status != InstitutionGroupListStatus.error || currentFailure == null) {
      return this;
    }

    return InstitutionGroupListState.error(
      query: query,
      searchDraft: searchDraft,
      failure: currentFailure,
      isRetryInFlight: true,
      recoveryWarning: recoveryWarning,
    );
  }
}
