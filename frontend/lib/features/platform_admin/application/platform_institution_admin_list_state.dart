import '../../../core/network/api_failure.dart';
import '../domain/platform_institution_admin_list.dart';
import '../domain/platform_institution_admin_list_query.dart';

class PlatformInstitutionAdminListKey {
  const PlatformInstitutionAdminListKey({
    required this.sessionUserId,
    required this.sessionInstanceId,
    required this.institutionId,
  });

  final String sessionUserId;
  final int sessionInstanceId;
  final String institutionId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlatformInstitutionAdminListKey &&
            other.sessionUserId == sessionUserId &&
            other.sessionInstanceId == sessionInstanceId &&
            other.institutionId == institutionId;
  }

  @override
  int get hashCode {
    return Object.hash(sessionUserId, sessionInstanceId, institutionId);
  }
}

enum PlatformInstitutionAdminListStatus {
  waitingForInstitutionDetail,
  initial,
  loading,
  queryLoading,
  data,
  globalEmpty,
  filteredEmpty,
  emptyPage,
  error,
}

class PlatformInstitutionAdminListState {
  const PlatformInstitutionAdminListState._({
    required this.status,
    required this.query,
    required this.searchText,
    required this.result,
    required this.failure,
    required this.isRetryInFlight,
    required this.searchErrorText,
  });

  const PlatformInstitutionAdminListState.waitingForInstitutionDetail()
    : this._(
        status: PlatformInstitutionAdminListStatus.waitingForInstitutionDetail,
        query: const PlatformInstitutionAdminListQuery.initial(),
        searchText: '',
        result: null,
        failure: null,
        isRetryInFlight: false,
        searchErrorText: null,
      );

  const PlatformInstitutionAdminListState.initial()
    : this._(
        status: PlatformInstitutionAdminListStatus.initial,
        query: const PlatformInstitutionAdminListQuery.initial(),
        searchText: '',
        result: null,
        failure: null,
        isRetryInFlight: false,
        searchErrorText: null,
      );

  const PlatformInstitutionAdminListState.loading({
    required PlatformInstitutionAdminListQuery query,
    required String searchText,
  }) : this._(
         status: PlatformInstitutionAdminListStatus.loading,
         query: query,
         searchText: searchText,
         result: null,
         failure: null,
         isRetryInFlight: false,
         searchErrorText: null,
       );

  const PlatformInstitutionAdminListState.queryLoading({
    required PlatformInstitutionAdminListQuery query,
    required String searchText,
  }) : this._(
         status: PlatformInstitutionAdminListStatus.queryLoading,
         query: query,
         searchText: searchText,
         result: null,
         failure: null,
         isRetryInFlight: false,
         searchErrorText: null,
       );

  factory PlatformInstitutionAdminListState.fromResult({
    required PlatformInstitutionAdminListQuery query,
    required String searchText,
    required PlatformInstitutionAdminList result,
  }) {
    return PlatformInstitutionAdminListState._(
      status: _statusFor(query, result),
      query: query,
      searchText: searchText,
      result: result,
      failure: null,
      isRetryInFlight: false,
      searchErrorText: null,
    );
  }

  const PlatformInstitutionAdminListState.error({
    required PlatformInstitutionAdminListQuery query,
    required String searchText,
    required ApiFailure failure,
    bool isRetryInFlight = false,
  }) : this._(
         status: PlatformInstitutionAdminListStatus.error,
         query: query,
         searchText: searchText,
         result: null,
         failure: failure,
         isRetryInFlight: isRetryInFlight,
         searchErrorText: null,
       );

  final PlatformInstitutionAdminListStatus status;
  final PlatformInstitutionAdminListQuery query;
  final String searchText;
  final PlatformInstitutionAdminList? result;
  final ApiFailure? failure;
  final bool isRetryInFlight;
  final String? searchErrorText;

  bool get hasRows => result?.admins.isNotEmpty ?? false;

  bool get isRequestInFlight {
    return status == PlatformInstitutionAdminListStatus.loading ||
        status == PlatformInstitutionAdminListStatus.queryLoading ||
        isRetryInFlight;
  }

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

  PlatformInstitutionAdminListState withSearchText(
    String value, {
    String? errorText,
  }) {
    return PlatformInstitutionAdminListState._(
      status: status,
      query: query,
      searchText: value,
      result: result,
      failure: failure,
      isRetryInFlight: isRetryInFlight,
      searchErrorText: errorText,
    );
  }

  PlatformInstitutionAdminListState retrying() {
    final currentFailure = failure;
    if (status != PlatformInstitutionAdminListStatus.error ||
        currentFailure == null) {
      return this;
    }

    return PlatformInstitutionAdminListState.error(
      query: query,
      searchText: searchText,
      failure: currentFailure,
      isRetryInFlight: true,
    );
  }

  static PlatformInstitutionAdminListStatus _statusFor(
    PlatformInstitutionAdminListQuery query,
    PlatformInstitutionAdminList result,
  ) {
    if (result.admins.isNotEmpty) {
      return PlatformInstitutionAdminListStatus.data;
    }

    if (query.page > 1) {
      return PlatformInstitutionAdminListStatus.emptyPage;
    }

    if (result.pagination.total == 0 && query.hasSearchOrFilter) {
      return PlatformInstitutionAdminListStatus.filteredEmpty;
    }

    if (result.pagination.total == 0) {
      return PlatformInstitutionAdminListStatus.globalEmpty;
    }

    return PlatformInstitutionAdminListStatus.data;
  }
}
