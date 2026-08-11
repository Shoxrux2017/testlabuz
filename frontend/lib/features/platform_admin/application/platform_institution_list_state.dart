import '../../../core/network/api_failure.dart';
import '../domain/platform_institution_list.dart';
import '../domain/platform_institution_list_query.dart';

enum PlatformInstitutionListStatus {
  initial,
  loading,
  queryLoading,
  data,
  globalEmpty,
  filteredEmpty,
  emptyPage,
  error,
}

class PlatformInstitutionListState {
  const PlatformInstitutionListState._({
    required this.status,
    required this.query,
    required this.searchText,
    required this.result,
    required this.failure,
    required this.isRetryInFlight,
    required this.searchErrorText,
  });

  const PlatformInstitutionListState.initial()
    : this._(
        status: PlatformInstitutionListStatus.initial,
        query: const PlatformInstitutionListQuery.initial(),
        searchText: '',
        result: null,
        failure: null,
        isRetryInFlight: false,
        searchErrorText: null,
      );

  const PlatformInstitutionListState.loading({
    required PlatformInstitutionListQuery query,
    required String searchText,
  }) : this._(
         status: PlatformInstitutionListStatus.loading,
         query: query,
         searchText: searchText,
         result: null,
         failure: null,
         isRetryInFlight: false,
         searchErrorText: null,
       );

  const PlatformInstitutionListState.queryLoading({
    required PlatformInstitutionListQuery query,
    required String searchText,
  }) : this._(
         status: PlatformInstitutionListStatus.queryLoading,
         query: query,
         searchText: searchText,
         result: null,
         failure: null,
         isRetryInFlight: false,
         searchErrorText: null,
       );

  factory PlatformInstitutionListState.fromResult({
    required PlatformInstitutionListQuery query,
    required String searchText,
    required PlatformInstitutionListPage result,
  }) {
    final status = _statusFor(query, result);

    return PlatformInstitutionListState._(
      status: status,
      query: query,
      searchText: searchText,
      result: result,
      failure: null,
      isRetryInFlight: false,
      searchErrorText: null,
    );
  }

  const PlatformInstitutionListState.error({
    required PlatformInstitutionListQuery query,
    required String searchText,
    required ApiFailure failure,
    bool isRetryInFlight = false,
  }) : this._(
         status: PlatformInstitutionListStatus.error,
         query: query,
         searchText: searchText,
         result: null,
         failure: failure,
         isRetryInFlight: isRetryInFlight,
         searchErrorText: null,
       );

  final PlatformInstitutionListStatus status;
  final PlatformInstitutionListQuery query;
  final String searchText;
  final PlatformInstitutionListPage? result;
  final ApiFailure? failure;
  final bool isRetryInFlight;
  final String? searchErrorText;

  bool get hasRows => result?.institutions.isNotEmpty ?? false;

  bool get isRequestInFlight =>
      status == PlatformInstitutionListStatus.loading ||
      status == PlatformInstitutionListStatus.queryLoading ||
      isRetryInFlight;

  bool get canGoPrevious {
    if (isRequestInFlight) {
      return false;
    }

    return (result?.pagination.page ?? query.page) > 1;
  }

  bool get canGoNext {
    if (isRequestInFlight || !hasRows) {
      return false;
    }

    final pagination = result?.pagination;
    if (pagination == null) {
      return false;
    }

    return pagination.page < pagination.lastPage;
  }

  PlatformInstitutionListState withSearchText(
    String value, {
    String? errorText,
  }) {
    return PlatformInstitutionListState._(
      status: status,
      query: query,
      searchText: value,
      result: result,
      failure: failure,
      isRetryInFlight: isRetryInFlight,
      searchErrorText: errorText,
    );
  }

  PlatformInstitutionListState retrying() {
    final currentFailure = failure;
    if (status != PlatformInstitutionListStatus.error ||
        currentFailure == null) {
      return this;
    }

    return PlatformInstitutionListState.error(
      query: query,
      searchText: searchText,
      failure: currentFailure,
      isRetryInFlight: true,
    );
  }

  static PlatformInstitutionListStatus _statusFor(
    PlatformInstitutionListQuery query,
    PlatformInstitutionListPage result,
  ) {
    if (result.institutions.isNotEmpty) {
      return PlatformInstitutionListStatus.data;
    }

    if (query.page > 1) {
      return PlatformInstitutionListStatus.emptyPage;
    }

    if (result.pagination.total == 0 && query.hasSearchOrFilter) {
      return PlatformInstitutionListStatus.filteredEmpty;
    }

    if (result.pagination.total == 0) {
      return PlatformInstitutionListStatus.globalEmpty;
    }

    return PlatformInstitutionListStatus.data;
  }
}
