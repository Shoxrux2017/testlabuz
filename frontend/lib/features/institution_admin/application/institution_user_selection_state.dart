import '../../../core/network/api_failure.dart';
import '../domain/institution_user.dart';
import '../domain/institution_user_list.dart';
import '../domain/institution_user_list_query.dart';
import '../domain/institution_user_selection.dart';

enum InstitutionUserSelectionStatus {
  closed,
  loading,
  data,
  empty,
  emptyPage,
  error,
}

class InstitutionUserSelectionState {
  const InstitutionUserSelectionState._({
    required this.purpose,
    required this.status,
    required this.query,
    required this.searchDraft,
    required this.result,
    required this.failure,
    required this.searchErrorText,
    required this.selected,
    required this.isRetryInFlight,
  });

  const InstitutionUserSelectionState.closed({
    required InstitutionUserSelectionPurpose purpose,
  }) : this._(
         purpose: purpose,
         status: InstitutionUserSelectionStatus.closed,
         query: null,
         searchDraft: '',
         result: null,
         failure: null,
         searchErrorText: null,
         selected: null,
         isRetryInFlight: false,
       );

  const InstitutionUserSelectionState.loading({
    required InstitutionUserSelectionPurpose purpose,
    required InstitutionUserListQuery query,
    required String searchDraft,
    required InstitutionUser? selected,
  }) : this._(
         purpose: purpose,
         status: InstitutionUserSelectionStatus.loading,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: null,
         searchErrorText: null,
         selected: selected,
         isRetryInFlight: false,
       );

  factory InstitutionUserSelectionState.fromResult({
    required InstitutionUserSelectionPurpose purpose,
    required InstitutionUserListQuery query,
    required String searchDraft,
    required InstitutionUserListPage result,
    required InstitutionUser? selected,
  }) => InstitutionUserSelectionState._(
    purpose: purpose,
    status: result.users.isNotEmpty
        ? InstitutionUserSelectionStatus.data
        : result.pagination.total == 0
        ? InstitutionUserSelectionStatus.empty
        : InstitutionUserSelectionStatus.emptyPage,
    query: query,
    searchDraft: searchDraft,
    result: result,
    failure: null,
    searchErrorText: null,
    selected: selected,
    isRetryInFlight: false,
  );

  const InstitutionUserSelectionState.error({
    required InstitutionUserSelectionPurpose purpose,
    required InstitutionUserListQuery query,
    required String searchDraft,
    required ApiFailure failure,
    required InstitutionUser? selected,
    bool isRetryInFlight = false,
  }) : this._(
         purpose: purpose,
         status: InstitutionUserSelectionStatus.error,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: failure,
         searchErrorText: null,
         selected: selected,
         isRetryInFlight: isRetryInFlight,
       );

  final InstitutionUserSelectionPurpose purpose;
  final InstitutionUserSelectionStatus status;
  final InstitutionUserListQuery? query;
  final String searchDraft;
  final InstitutionUserListPage? result;
  final ApiFailure? failure;
  final String? searchErrorText;
  final InstitutionUser? selected;
  final bool isRetryInFlight;

  bool get isOpen => status != InstitutionUserSelectionStatus.closed;
  bool get isRequestInFlight =>
      status == InstitutionUserSelectionStatus.loading || isRetryInFlight;
  bool get canGoPrevious =>
      !isRequestInFlight && searchErrorText == null && (query?.page ?? 1) > 1;

  bool get canGoNext {
    final pagination = result?.pagination;
    return !isRequestInFlight &&
        searchErrorText == null &&
        pagination != null &&
        pagination.page < pagination.lastPage;
  }

  InstitutionUserSelectionState withSearchDraft(
    String value, {
    String? errorText,
  }) => InstitutionUserSelectionState._(
    purpose: purpose,
    status: status,
    query: query,
    searchDraft: value,
    result: result,
    failure: failure,
    searchErrorText: errorText,
    selected: selected,
    isRetryInFlight: isRetryInFlight,
  );

  InstitutionUserSelectionState withSelection(InstitutionUser? value) =>
      InstitutionUserSelectionState._(
        purpose: purpose,
        status: status,
        query: query,
        searchDraft: searchDraft,
        result: result,
        failure: failure,
        searchErrorText: searchErrorText,
        selected: value,
        isRetryInFlight: isRetryInFlight,
      );

  InstitutionUserSelectionState retrying() {
    final currentQuery = query;
    final currentFailure = failure;
    if (status != InstitutionUserSelectionStatus.error ||
        currentQuery == null ||
        currentFailure == null) {
      return this;
    }
    return InstitutionUserSelectionState.error(
      purpose: purpose,
      query: currentQuery,
      searchDraft: searchDraft,
      failure: currentFailure,
      selected: selected,
      isRetryInFlight: true,
    );
  }
}
