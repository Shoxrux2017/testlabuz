import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/domain/user_role.dart';
import '../data/institution_parent_student_relationship_repository_impl.dart';
import '../domain/institution_parent_student_relationship.dart';
import '../domain/institution_parent_student_relationship_list.dart';
import '../domain/institution_parent_student_relationship_mutation.dart';
import '../domain/institution_parent_student_relationship_query.dart';
import '../domain/institution_user.dart';
import 'institution_parent_student_relationship_list_state.dart';

final institutionParentStudentRelationshipListControllerProvider =
    NotifierProvider.autoDispose.family<
      InstitutionParentStudentRelationshipListController,
      InstitutionParentStudentRelationshipListState,
      InstitutionParentStudentPerspective
    >(InstitutionParentStudentRelationshipListController.new);

class InstitutionParentStudentRelationshipListController
    extends Notifier<InstitutionParentStudentRelationshipListState> {
  InstitutionParentStudentRelationshipListController(this.perspective);

  final InstitutionParentStudentPerspective perspective;

  InstitutionParentStudentSessionKey? _activeSessionKey;
  InstitutionUser? _activeAnchor;
  InstitutionParentStudentRelationshipQuery? _inFlightQuery;
  Timer? _searchDebounce;
  int _operationGeneration = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  InstitutionParentStudentRelationshipListState build() {
    _isDisposed = false;
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() {
        _isDisposed = true;
        _searchDebounce?.cancel();
        _invalidateOperations();
      });
    }
    final sessionKey = InstitutionParentStudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null) {
      _clearOwnership();
      return InstitutionParentStudentRelationshipListState.noAnchor(
        perspective: perspective,
      );
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }
    _clearOwnership();
    _activeSessionKey = sessionKey;
    return InstitutionParentStudentRelationshipListState.noAnchor(
      perspective: perspective,
    );
  }

  void selectAnchor(InstitutionUser anchor) {
    _selectAnchorWithQuery(
      anchor,
      const InstitutionParentStudentRelationshipQuery.initial(),
      checking: false,
    );
  }

  Future<void> selectAnchorForMutation(
    InstitutionUser anchor, {
    InstitutionParentStudentRelationshipQuery? query,
    bool preserveQueryForSameAnchor = false,
  }) {
    final sameAnchor =
        _activeAnchor != null &&
        _activeAnchor!.id.toLowerCase() == anchor.id.toLowerCase();
    final selectedQuery =
        query ??
        (sameAnchor && preserveQueryForSameAnchor
            ? state.query
            : const InstitutionParentStudentRelationshipQuery.initial());
    final selectedSearchDraft =
        query == null && sameAnchor && preserveQueryForSameAnchor
        ? state.searchDraft
        : '';
    return _selectAnchorWithQuery(
      anchor,
      selectedQuery,
      searchDraft: selectedSearchDraft,
      checking: true,
      retainCurrentResult: sameAnchor,
    );
  }

  void clearAnchor() {
    _searchDebounce?.cancel();
    _activeAnchor = null;
    _invalidateOperations();
    state = InstitutionParentStudentRelationshipListState.noAnchor(
      perspective: perspective,
    );
  }

  void updateSearchDraft(String value) {
    if (state.anchor == null || state.projectionStale) {
      return;
    }
    final valid = InstitutionParentStudentRelationshipQuery.isSearchInputValid(
      value,
    );
    _searchDebounce?.cancel();
    state = state.withSearchDraft(
      value,
      errorText: valid ? null : 'Search must be 254 characters or fewer.',
    );
    if (valid) {
      _searchDebounce = Timer(
        InstitutionParentStudentRelationshipQuery.searchDebounceDuration,
        commitSearchNow,
      );
    }
  }

  void commitSearchNow() {
    _searchDebounce?.cancel();
    if (!_hasValidSearchDraft()) {
      return;
    }
    _commitQuery(
      state.query.withSearch(
        InstitutionParentStudentRelationshipQuery.normalizeSearch(
          state.searchDraft,
        ),
      ),
    );
  }

  void setStatus(InstitutionParentStudentRelationshipStatusFilter? status) {
    final base = _queryWithCommittedDraft();
    if (base != null) {
      _commitQuery(base.withStatus(status));
    }
  }

  void toggleSort(InstitutionParentStudentRelationshipSort sort) {
    final base = _queryWithCommittedDraft();
    if (base != null) {
      _commitQuery(base.withSort(sort));
    }
  }

  void setPerPage(int perPage) {
    final base = _queryWithCommittedDraft();
    if (base != null) {
      _commitQuery(base.withPerPage(perPage));
    }
  }

  void previousPage() {
    if (!_hasValidSearchDraft() || state.isRequestInFlight) {
      return;
    }
    final pending = _queryWithCommittedDraft();
    if (pending == null) {
      return;
    }
    if (pending.search != state.query.search) {
      _commitQuery(pending);
    } else if (state.canGoPrevious) {
      _commitQuery(state.query.withPage(state.query.page - 1));
    }
  }

  void nextPage() {
    if (!_hasValidSearchDraft() || state.isRequestInFlight) {
      return;
    }
    final pending = _queryWithCommittedDraft();
    if (pending == null) {
      return;
    }
    if (pending.search != state.query.search) {
      _commitQuery(pending);
    } else if (state.canGoNext) {
      _commitQuery(state.query.withPage(state.query.page + 1));
    }
  }

  void clearFilters() {
    if (state.anchor == null) {
      return;
    }
    _searchDebounce?.cancel();
    final query = state.query.clearSearchAndStatus();
    state = state.withSearchDraft('');
    if (query != state.query) {
      _commitQuery(query, searchDraft: '');
    }
  }

  void refresh() {
    if (!_hasValidSearchDraft() || state.isRequestInFlight) {
      return;
    }
    final query = _queryWithCommittedDraft();
    if (query == null) {
      return;
    }
    unawaited(
      _startLogicalLoad(
        query,
        searchDraft: state.searchDraft,
        presentation: query == state.query && state.result != null
            ? _RelationshipLoadPresentation.refresh
            : _RelationshipLoadPresentation.query,
      ),
    );
  }

  void retry() {
    if (state.status != InstitutionParentStudentRelationshipListStatus.error ||
        state.isRetryInFlight ||
        _inFlightQuery != null) {
      return;
    }
    _searchDebounce?.cancel();
    unawaited(
      _startLogicalLoad(
        state.query,
        searchDraft: state.searchDraft,
        presentation: _RelationshipLoadPresentation.retry,
      ),
    );
  }

  void markStale() {
    _searchDebounce?.cancel();
    _invalidateOperations();
    state = state.asStale();
  }

  Future<void> activate() async {
    if (state.projectionStale) {
      await markCheckingAndReload();
    }
  }

  Future<void> markCheckingAndReload() async {
    if (_activeAnchor == null || _activeSessionKey == null) {
      return;
    }
    _searchDebounce?.cancel();
    await _startLogicalLoad(
      state.query,
      searchDraft: state.searchDraft,
      presentation: _RelationshipLoadPresentation.checking,
      checkingResult: state.result,
    );
  }

  bool hasAnchorId(String id) =>
      _activeAnchor?.id.toLowerCase() == id.toLowerCase();

  bool ownsCurrentRelationship(
    InstitutionParentStudentRelationshipIdentity identity,
  ) {
    final anchor = _activeAnchor;
    if (anchor == null ||
        identity.perspective != perspective ||
        state.status != InstitutionParentStudentRelationshipListStatus.data) {
      return false;
    }
    return state.result?.relationships.any(
          (relationship) => identity.matches(
            currentPerspective: perspective,
            currentAnchor: anchor,
            currentRelationship: relationship,
          ),
        ) ??
        false;
  }

  Future<void> _selectAnchorWithQuery(
    InstitutionUser anchor,
    InstitutionParentStudentRelationshipQuery query, {
    String searchDraft = '',
    required bool checking,
    bool retainCurrentResult = false,
  }) async {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        anchor.role != perspective.anchorRole ||
        !isCanonicalParentStudentUuid(anchor.id) ||
        !_matchesSession(sessionKey)) {
      return;
    }
    _searchDebounce?.cancel();
    final checkingResult = retainCurrentResult ? state.result : null;
    _invalidateOperations();
    _activeAnchor = anchor;
    await _startLogicalLoad(
      query,
      searchDraft: searchDraft,
      presentation: checking
          ? _RelationshipLoadPresentation.checking
          : _RelationshipLoadPresentation.initial,
      checkingResult: checkingResult,
    );
  }

  InstitutionParentStudentRelationshipQuery? _queryWithCommittedDraft() {
    _searchDebounce?.cancel();
    if (!_hasValidSearchDraft()) {
      return null;
    }
    final normalized =
        InstitutionParentStudentRelationshipQuery.normalizeSearch(
          state.searchDraft,
        );
    return normalized == state.query.search
        ? state.query
        : state.query.withSearch(normalized);
  }

  bool _hasValidSearchDraft() {
    if (state.anchor == null || state.projectionStale) {
      return false;
    }
    if (InstitutionParentStudentRelationshipQuery.isSearchInputValid(
      state.searchDraft,
    )) {
      return true;
    }
    state = state.withSearchDraft(
      state.searchDraft,
      errorText: 'Search must be 254 characters or fewer.',
    );
    return false;
  }

  void _commitQuery(
    InstitutionParentStudentRelationshipQuery query, {
    String? searchDraft,
  }) {
    final nextDraft = searchDraft ?? state.searchDraft;
    if (query == state.query) {
      if (nextDraft != state.searchDraft || state.searchErrorText != null) {
        state = state.withSearchDraft(nextDraft);
      }
      return;
    }
    unawaited(
      _startLogicalLoad(
        query,
        searchDraft: nextDraft,
        presentation: _RelationshipLoadPresentation.query,
      ),
    );
  }

  Future<void> _startLogicalLoad(
    InstitutionParentStudentRelationshipQuery query, {
    required String searchDraft,
    required _RelationshipLoadPresentation presentation,
    InstitutionParentStudentRelationshipListPage? checkingResult,
  }) async {
    final sessionKey = _activeSessionKey;
    final anchor = _activeAnchor;
    if (sessionKey == null ||
        anchor == null ||
        !_matchesSession(sessionKey) ||
        (_inFlightQuery == query && state.isRequestInFlight)) {
      return;
    }
    final generation = ++_operationGeneration;
    _inFlightQuery = query;
    final searchErrorText = searchDraft == state.searchDraft
        ? state.searchErrorText
        : null;
    state = switch (presentation) {
      _RelationshipLoadPresentation.initial =>
        InstitutionParentStudentRelationshipListState.loading(
          perspective: perspective,
          anchor: anchor,
          query: query,
          searchDraft: searchDraft,
          searchErrorText: searchErrorText,
        ),
      _RelationshipLoadPresentation.query =>
        InstitutionParentStudentRelationshipListState.loading(
          perspective: perspective,
          anchor: anchor,
          query: query,
          searchDraft: searchDraft,
          searchErrorText: searchErrorText,
          status: InstitutionParentStudentRelationshipListStatus.queryLoading,
        ),
      _RelationshipLoadPresentation.refresh =>
        InstitutionParentStudentRelationshipListState.loading(
          perspective: perspective,
          anchor: anchor,
          query: query,
          searchDraft: searchDraft,
          searchErrorText: searchErrorText,
          status: InstitutionParentStudentRelationshipListStatus.refreshing,
          result: state.result,
        ),
      _RelationshipLoadPresentation.retry => state.retrying(),
      _RelationshipLoadPresentation.checking =>
        InstitutionParentStudentRelationshipListState.loading(
          perspective: perspective,
          anchor: anchor,
          query: query,
          searchDraft: searchDraft,
          searchErrorText: searchErrorText,
          status: InstitutionParentStudentRelationshipListStatus
              .checkingCurrentState,
          result: checkingResult,
        ),
    };
    await _load(
      query,
      anchor: anchor,
      sessionKey: sessionKey,
      generation: generation,
      correctionUsed: false,
    );
  }

  Future<void> _load(
    InstitutionParentStudentRelationshipQuery query, {
    required InstitutionUser anchor,
    required InstitutionParentStudentSessionKey sessionKey,
    required int generation,
    required bool correctionUsed,
  }) async {
    try {
      final result = await ref
          .read(institutionParentStudentRelationshipRepositoryProvider)
          .fetchRelationships(
            perspective: perspective,
            anchorId: anchor.id,
            query: query,
          );
      if (!_canPublish(generation, sessionKey, anchor, query)) {
        return;
      }
      final correction = _correctionTarget(
        query,
        result,
        correctionUsed: correctionUsed,
      );
      if (correction != null) {
        final corrected = query.withPage(correction);
        _inFlightQuery = corrected;
        state = InstitutionParentStudentRelationshipListState.loading(
          perspective: perspective,
          anchor: anchor,
          query: corrected,
          searchDraft: state.searchDraft,
          searchErrorText: state.searchErrorText,
          status: InstitutionParentStudentRelationshipListStatus.queryLoading,
        );
        await _load(
          corrected,
          anchor: anchor,
          sessionKey: sessionKey,
          generation: generation,
          correctionUsed: true,
        );
        return;
      }
      state = InstitutionParentStudentRelationshipListState.fromResult(
        perspective: perspective,
        anchor: anchor,
        query: query,
        searchDraft: state.searchDraft,
        searchErrorText: state.searchErrorText,
        result: result,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey, anchor, query)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      if (_isExactNotFound(exception.failure)) {
        _activeAnchor = null;
        _invalidateOperations();
        state = InstitutionParentStudentRelationshipListState.noAnchor(
          perspective: perspective,
          feedback:
              'The selected user is no longer available for relationship management.',
        );
        return;
      }
      state = InstitutionParentStudentRelationshipListState.error(
        perspective: perspective,
        anchor: anchor,
        query: query,
        searchDraft: state.searchDraft,
        failure: exception.failure,
        searchErrorText: state.searchErrorText,
      );
    } catch (_) {
      if (_canPublish(generation, sessionKey, anchor, query)) {
        state = InstitutionParentStudentRelationshipListState.error(
          perspective: perspective,
          anchor: anchor,
          query: query,
          searchDraft: state.searchDraft,
          failure: ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Current relationships could not be loaded safely.',
          ),
          searchErrorText: state.searchErrorText,
        );
      }
    } finally {
      if (generation == _operationGeneration && _inFlightQuery == query) {
        _inFlightQuery = null;
      }
    }
  }

  int? _correctionTarget(
    InstitutionParentStudentRelationshipQuery query,
    InstitutionParentStudentRelationshipListPage result, {
    required bool correctionUsed,
  }) {
    if (correctionUsed ||
        result.relationships.isNotEmpty ||
        query.page <= InstitutionParentStudentRelationshipQuery.initialPage) {
      return null;
    }
    final target = result.pagination.total == 0
        ? 1
        : math.max(1, math.min(result.pagination.lastPage, query.page - 1));
    return target == query.page ? null : target;
  }

  bool _canPublish(
    int generation,
    InstitutionParentStudentSessionKey sessionKey,
    InstitutionUser anchor,
    InstitutionParentStudentRelationshipQuery query,
  ) =>
      !_isDisposed &&
      generation == _operationGeneration &&
      _inFlightQuery == query &&
      identical(_activeAnchor, anchor) &&
      _matchesSession(sessionKey);

  bool _matchesSession(InstitutionParentStudentSessionKey sessionKey) =>
      !_isDisposed &&
      _activeSessionKey == sessionKey &&
      InstitutionParentStudentSessionSnapshot.fromSession(
            ref.read(authSessionControllerProvider),
            ref.read(appDeviceSurfaceProvider),
          ).eligibleKey ==
          sessionKey;

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }
    _clearOwnership();
    state = InstitutionParentStudentRelationshipListState.noAnchor(
      perspective: perspective,
    );
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  bool _isExactNotFound(ApiFailure failure) =>
      failure.statusCode == 404 &&
      failure.serverCode == ApiErrorCodes.resourceNotFound;

  void _clearOwnership() {
    _activeSessionKey = null;
    _activeAnchor = null;
    _searchDebounce?.cancel();
    _invalidateOperations();
  }

  void _invalidateOperations() {
    _operationGeneration += 1;
    _inFlightQuery = null;
  }
}

class InstitutionParentStudentSessionSnapshot {
  const InstitutionParentStudentSessionSnapshot({
    required this.status,
    required this.user,
    required this.surface,
  });

  factory InstitutionParentStudentSessionSnapshot.fromSession(
    AuthSessionState session,
    AppDeviceSurface surface,
  ) => InstitutionParentStudentSessionSnapshot(
    status: session.status,
    user: session.user,
    surface: surface,
  );

  final AuthSessionStatus status;
  final AuthUser? user;
  final AppDeviceSurface surface;

  InstitutionParentStudentSessionKey? get eligibleKey {
    final currentUser = user;
    final institutionId = currentUser?.institutionId;
    final institution = currentUser?.institution;
    if (status != AuthSessionStatus.authenticated ||
        currentUser == null ||
        currentUser.id.isEmpty ||
        currentUser.role != UserRole.institutionAdmin ||
        !currentUser.isActive ||
        currentUser.mustChangePassword ||
        institutionId == null ||
        institutionId.trim().isEmpty ||
        institution == null ||
        institution.id != institutionId ||
        institution.status != 'active' ||
        surface != AppDeviceSurface.desktop) {
      return null;
    }
    return InstitutionParentStudentSessionKey(
      userId: currentUser.id,
      userInstance: currentUser,
      institutionId: institutionId,
    );
  }
}

class InstitutionParentStudentSessionKey {
  const InstitutionParentStudentSessionKey({
    required this.userId,
    required this.userInstance,
    required this.institutionId,
  });

  final String userId;
  final AuthUser userInstance;
  final String institutionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstitutionParentStudentSessionKey &&
          other.userId == userId &&
          identical(other.userInstance, userInstance) &&
          other.institutionId == institutionId;

  @override
  int get hashCode =>
      Object.hash(userId, identityHashCode(userInstance), institutionId);
}

enum _RelationshipLoadPresentation { initial, query, refresh, retry, checking }
