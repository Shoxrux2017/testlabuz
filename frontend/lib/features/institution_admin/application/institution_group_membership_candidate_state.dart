import '../../../core/network/api_failure.dart';
import '../domain/institution_group.dart';
import '../domain/institution_user.dart';
import '../domain/institution_user_list.dart';
import '../domain/institution_user_list_query.dart';

enum InstitutionGroupMembershipCandidateStatus {
  closed,
  loading,
  data,
  empty,
  emptyPage,
  error,
}

class InstitutionGroupMembershipCandidateState {
  const InstitutionGroupMembershipCandidateState._({
    required this.status,
    required this.group,
    required this.query,
    required this.searchDraft,
    required this.result,
    required this.failure,
    required this.searchErrorText,
    required this.selected,
    required this.isRetryInFlight,
  });

  const InstitutionGroupMembershipCandidateState.closed()
    : this._(
        status: InstitutionGroupMembershipCandidateStatus.closed,
        group: null,
        query: null,
        searchDraft: '',
        result: null,
        failure: null,
        searchErrorText: null,
        selected: const [],
        isRetryInFlight: false,
      );

  const InstitutionGroupMembershipCandidateState.loading({
    required InstitutionGroup group,
    required InstitutionUserListQuery query,
    required String searchDraft,
    required List<InstitutionUser> selected,
  }) : this._(
         status: InstitutionGroupMembershipCandidateStatus.loading,
         group: group,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: null,
         searchErrorText: null,
         selected: selected,
         isRetryInFlight: false,
       );

  factory InstitutionGroupMembershipCandidateState.fromResult({
    required InstitutionGroup group,
    required InstitutionUserListQuery query,
    required String searchDraft,
    required InstitutionUserListPage result,
    required List<InstitutionUser> selected,
  }) => InstitutionGroupMembershipCandidateState._(
    status: result.users.isNotEmpty
        ? InstitutionGroupMembershipCandidateStatus.data
        : result.pagination.total == 0
        ? InstitutionGroupMembershipCandidateStatus.empty
        : InstitutionGroupMembershipCandidateStatus.emptyPage,
    group: group,
    query: query,
    searchDraft: searchDraft,
    result: result,
    failure: null,
    searchErrorText: null,
    selected: selected,
    isRetryInFlight: false,
  );

  const InstitutionGroupMembershipCandidateState.error({
    required InstitutionGroup group,
    required InstitutionUserListQuery query,
    required String searchDraft,
    required ApiFailure failure,
    required List<InstitutionUser> selected,
    bool isRetryInFlight = false,
  }) : this._(
         status: InstitutionGroupMembershipCandidateStatus.error,
         group: group,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: failure,
         searchErrorText: null,
         selected: selected,
         isRetryInFlight: isRetryInFlight,
       );

  final InstitutionGroupMembershipCandidateStatus status;
  final InstitutionGroup? group;
  final InstitutionUserListQuery? query;
  final String searchDraft;
  final InstitutionUserListPage? result;
  final ApiFailure? failure;
  final String? searchErrorText;
  final List<InstitutionUser> selected;
  final bool isRetryInFlight;

  bool get isOpen => status != InstitutionGroupMembershipCandidateStatus.closed;
  bool get isRequestInFlight =>
      status == InstitutionGroupMembershipCandidateStatus.loading ||
      isRetryInFlight;
  bool get canGoPrevious =>
      !isRequestInFlight && searchErrorText == null && (query?.page ?? 1) > 1;
  bool get canGoNext {
    final pagination = result?.pagination;
    return !isRequestInFlight &&
        searchErrorText == null &&
        pagination != null &&
        pagination.page < pagination.lastPage;
  }

  bool isSelected(InstitutionUser user) => selected.any(
    (candidate) => candidate.id.toLowerCase() == user.id.toLowerCase(),
  );

  InstitutionGroupMembershipCandidateState withSearchDraft(
    String value, {
    String? errorText,
  }) => InstitutionGroupMembershipCandidateState._(
    status: status,
    group: group,
    query: query,
    searchDraft: value,
    result: result,
    failure: failure,
    searchErrorText: errorText,
    selected: selected,
    isRetryInFlight: isRetryInFlight,
  );

  InstitutionGroupMembershipCandidateState withSelection(
    List<InstitutionUser> value,
  ) => InstitutionGroupMembershipCandidateState._(
    status: status,
    group: group,
    query: query,
    searchDraft: searchDraft,
    result: result,
    failure: failure,
    searchErrorText: searchErrorText,
    selected: List.unmodifiable(value),
    isRetryInFlight: isRetryInFlight,
  );

  InstitutionGroupMembershipCandidateState retrying() {
    if (status != InstitutionGroupMembershipCandidateStatus.error ||
        failure == null ||
        group == null ||
        query == null) {
      return this;
    }
    return InstitutionGroupMembershipCandidateState.error(
      group: group!,
      query: query!,
      searchDraft: searchDraft,
      failure: failure!,
      selected: selected,
      isRetryInFlight: true,
    );
  }
}
