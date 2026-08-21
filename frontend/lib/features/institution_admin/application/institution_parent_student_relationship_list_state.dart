import '../../../core/network/api_failure.dart';
import '../domain/institution_parent_student_relationship.dart';
import '../domain/institution_parent_student_relationship_list.dart';
import '../domain/institution_parent_student_relationship_query.dart';
import '../domain/institution_user.dart';

enum InstitutionParentStudentRelationshipListStatus {
  noAnchor,
  loading,
  queryLoading,
  refreshing,
  checkingCurrentState,
  data,
  globalEmpty,
  filteredEmpty,
  emptyPage,
  error,
}

class InstitutionParentStudentRelationshipListState {
  const InstitutionParentStudentRelationshipListState._({
    required this.perspective,
    required this.status,
    required this.anchor,
    required this.query,
    required this.searchDraft,
    required this.result,
    required this.failure,
    required this.searchErrorText,
    required this.isRetryInFlight,
    required this.projectionStale,
    required this.feedback,
  });

  const InstitutionParentStudentRelationshipListState.noAnchor({
    required InstitutionParentStudentPerspective perspective,
    String? feedback,
  }) : this._(
         perspective: perspective,
         status: InstitutionParentStudentRelationshipListStatus.noAnchor,
         anchor: null,
         query: const InstitutionParentStudentRelationshipQuery.initial(),
         searchDraft: '',
         result: null,
         failure: null,
         searchErrorText: null,
         isRetryInFlight: false,
         projectionStale: false,
         feedback: feedback,
       );

  const InstitutionParentStudentRelationshipListState.loading({
    required InstitutionParentStudentPerspective perspective,
    required InstitutionUser anchor,
    required InstitutionParentStudentRelationshipQuery query,
    required String searchDraft,
    InstitutionParentStudentRelationshipListStatus status =
        InstitutionParentStudentRelationshipListStatus.loading,
    InstitutionParentStudentRelationshipListPage? result,
    String? searchErrorText,
  }) : this._(
         perspective: perspective,
         status: status,
         anchor: anchor,
         query: query,
         searchDraft: searchDraft,
         result: result,
         failure: null,
         searchErrorText: searchErrorText,
         isRetryInFlight: false,
         projectionStale:
             status ==
             InstitutionParentStudentRelationshipListStatus
                 .checkingCurrentState,
         feedback: null,
       );

  factory InstitutionParentStudentRelationshipListState.fromResult({
    required InstitutionParentStudentPerspective perspective,
    required InstitutionUser anchor,
    required InstitutionParentStudentRelationshipQuery query,
    required String searchDraft,
    required InstitutionParentStudentRelationshipListPage result,
    String? searchErrorText,
  }) {
    final status = switch ((
      result.relationships.isNotEmpty,
      result.pagination.total,
    )) {
      (true, _) => InstitutionParentStudentRelationshipListStatus.data,
      (false, 0) when query.hasSearchOrFilter =>
        InstitutionParentStudentRelationshipListStatus.filteredEmpty,
      (false, 0) => InstitutionParentStudentRelationshipListStatus.globalEmpty,
      (false, _) => InstitutionParentStudentRelationshipListStatus.emptyPage,
    };
    return InstitutionParentStudentRelationshipListState._(
      perspective: perspective,
      status: status,
      anchor: anchor,
      query: query,
      searchDraft: searchDraft,
      result: result,
      failure: null,
      searchErrorText: searchErrorText,
      isRetryInFlight: false,
      projectionStale: false,
      feedback: null,
    );
  }

  const InstitutionParentStudentRelationshipListState.error({
    required InstitutionParentStudentPerspective perspective,
    required InstitutionUser anchor,
    required InstitutionParentStudentRelationshipQuery query,
    required String searchDraft,
    required ApiFailure failure,
    bool isRetryInFlight = false,
    String? searchErrorText,
  }) : this._(
         perspective: perspective,
         status: InstitutionParentStudentRelationshipListStatus.error,
         anchor: anchor,
         query: query,
         searchDraft: searchDraft,
         result: null,
         failure: failure,
         searchErrorText: searchErrorText,
         isRetryInFlight: isRetryInFlight,
         projectionStale: false,
         feedback: null,
       );

  final InstitutionParentStudentPerspective perspective;
  final InstitutionParentStudentRelationshipListStatus status;
  final InstitutionUser? anchor;
  final InstitutionParentStudentRelationshipQuery query;
  final String searchDraft;
  final InstitutionParentStudentRelationshipListPage? result;
  final ApiFailure? failure;
  final String? searchErrorText;
  final bool isRetryInFlight;
  final bool projectionStale;
  final String? feedback;

  bool get hasRows => result?.relationships.isNotEmpty ?? false;

  bool get isRequestInFlight =>
      status == InstitutionParentStudentRelationshipListStatus.loading ||
      status == InstitutionParentStudentRelationshipListStatus.queryLoading ||
      status == InstitutionParentStudentRelationshipListStatus.refreshing ||
      status ==
          InstitutionParentStudentRelationshipListStatus.checkingCurrentState ||
      isRetryInFlight;

  bool get canChangeQuery =>
      anchor != null &&
      !isRequestInFlight &&
      !projectionStale &&
      searchErrorText == null;

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
      anchor != null &&
      (searchDraft.isNotEmpty ||
          searchErrorText != null ||
          query.search != null ||
          query.status != null ||
          query.page != InstitutionParentStudentRelationshipQuery.initialPage);

  InstitutionParentStudentRelationshipListState withSearchDraft(
    String value, {
    String? errorText,
  }) => InstitutionParentStudentRelationshipListState._(
    perspective: perspective,
    status: status,
    anchor: anchor,
    query: query,
    searchDraft: value,
    result: result,
    failure: failure,
    searchErrorText: errorText,
    isRetryInFlight: isRetryInFlight,
    projectionStale: projectionStale,
    feedback: feedback,
  );

  InstitutionParentStudentRelationshipListState asStale() {
    if (anchor == null || projectionStale) {
      return this;
    }
    return InstitutionParentStudentRelationshipListState._(
      perspective: perspective,
      status: status,
      anchor: anchor,
      query: query,
      searchDraft: searchDraft,
      result: result,
      failure: failure,
      searchErrorText: searchErrorText,
      isRetryInFlight: isRetryInFlight,
      projectionStale: true,
      feedback: feedback,
    );
  }

  InstitutionParentStudentRelationshipListState retrying() {
    final currentAnchor = anchor;
    final currentFailure = failure;
    if (status != InstitutionParentStudentRelationshipListStatus.error ||
        currentAnchor == null ||
        currentFailure == null) {
      return this;
    }
    return InstitutionParentStudentRelationshipListState.error(
      perspective: perspective,
      anchor: currentAnchor,
      query: query,
      searchDraft: searchDraft,
      failure: currentFailure,
      isRetryInFlight: true,
      searchErrorText: searchErrorText,
    );
  }
}
