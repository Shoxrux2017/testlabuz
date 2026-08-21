import '../../../core/network/api_failure.dart';
import '../domain/institution_group_membership_list.dart';
import '../domain/institution_group_membership_query.dart';

enum InstitutionGroupMembershipListStatus {
  initial,
  loading,
  queryLoading,
  refreshing,
  data,
  globalEmpty,
  filteredEmpty,
  emptyPage,
  checkingCurrentState,
  error,
}

class InstitutionGroupMembershipListState {
  const InstitutionGroupMembershipListState._({
    required this.status,
    required this.query,
    required this.searchDraft,
    required this.result,
    required this.failure,
    required this.searchErrorText,
    required this.isRetryInFlight,
  });

  const InstitutionGroupMembershipListState.initial()
    : this._(
        status: InstitutionGroupMembershipListStatus.initial,
        query: const InstitutionGroupMembershipQuery.initial(),
        searchDraft: '',
        result: null,
        failure: null,
        searchErrorText: null,
        isRetryInFlight: false,
      );

  const InstitutionGroupMembershipListState.loading({
    required InstitutionGroupMembershipQuery query,
    required String searchDraft,
    InstitutionGroupMembershipListStatus status =
        InstitutionGroupMembershipListStatus.loading,
  }) : this._(
         status: status,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
       );

  const InstitutionGroupMembershipListState.refreshing({
    required InstitutionGroupMembershipQuery query,
    required String searchDraft,
    required InstitutionGroupMembershipListPage result,
  }) : this._(
         status: InstitutionGroupMembershipListStatus.refreshing,
         query: query,
         searchDraft: searchDraft,
         result: result,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
       );

  const InstitutionGroupMembershipListState.checkingCurrentState({
    required InstitutionGroupMembershipQuery query,
    required String searchDraft,
    InstitutionGroupMembershipListPage? result,
  }) : this._(
         status: InstitutionGroupMembershipListStatus.checkingCurrentState,
         query: query,
         searchDraft: searchDraft,
         result: result,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
       );

  factory InstitutionGroupMembershipListState.fromResult({
    required InstitutionGroupMembershipQuery query,
    required String searchDraft,
    required InstitutionGroupMembershipListPage result,
  }) {
    final status = switch ((
      result.memberships.isNotEmpty,
      result.pagination.total,
    )) {
      (true, _) => InstitutionGroupMembershipListStatus.data,
      (false, 0) when query.hasSearchOrFilter =>
        InstitutionGroupMembershipListStatus.filteredEmpty,
      (false, 0) => InstitutionGroupMembershipListStatus.globalEmpty,
      (false, _) => InstitutionGroupMembershipListStatus.emptyPage,
    };
    return InstitutionGroupMembershipListState._(
      status: status,
      query: query,
      searchDraft: searchDraft,
      result: result,
      failure: null,
      searchErrorText: null,
      isRetryInFlight: false,
    );
  }

  const InstitutionGroupMembershipListState.error({
    required InstitutionGroupMembershipQuery query,
    required String searchDraft,
    required ApiFailure failure,
    bool isRetryInFlight = false,
  }) : this._(
         status: InstitutionGroupMembershipListStatus.error,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: failure,
         searchErrorText: null,
         isRetryInFlight: isRetryInFlight,
       );

  final InstitutionGroupMembershipListStatus status;
  final InstitutionGroupMembershipQuery query;
  final String searchDraft;
  final InstitutionGroupMembershipListPage? result;
  final ApiFailure? failure;
  final String? searchErrorText;
  final bool isRetryInFlight;

  bool get hasRows => result?.memberships.isNotEmpty ?? false;

  bool get isRequestInFlight =>
      status == InstitutionGroupMembershipListStatus.loading ||
      status == InstitutionGroupMembershipListStatus.queryLoading ||
      status == InstitutionGroupMembershipListStatus.refreshing ||
      status == InstitutionGroupMembershipListStatus.checkingCurrentState ||
      isRetryInFlight;

  bool get canChangeQuery => !isRequestInFlight && searchErrorText == null;

  bool get canGoPrevious =>
      canChangeQuery && (result?.pagination.page ?? query.page) > 1;

  bool get canGoNext {
    final pagination = result?.pagination;
    return canChangeQuery &&
        hasRows &&
        pagination != null &&
        pagination.page < pagination.lastPage;
  }

  bool get canClearFilters =>
      searchDraft.isNotEmpty ||
      searchErrorText != null ||
      query.search != null ||
      query.status != null ||
      query.page != InstitutionGroupMembershipQuery.initialPage;

  InstitutionGroupMembershipListState withSearchDraft(
    String value, {
    String? errorText,
  }) => InstitutionGroupMembershipListState._(
    status: status,
    query: query,
    searchDraft: value,
    result: result,
    failure: failure,
    searchErrorText: errorText,
    isRetryInFlight: isRetryInFlight,
  );

  InstitutionGroupMembershipListState retrying() {
    final currentFailure = failure;
    if (status != InstitutionGroupMembershipListStatus.error ||
        currentFailure == null) {
      return this;
    }
    return InstitutionGroupMembershipListState.error(
      query: query,
      searchDraft: searchDraft,
      failure: currentFailure,
      isRetryInFlight: true,
    );
  }
}
