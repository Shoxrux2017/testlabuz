import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/user_role.dart';
import '../data/institution_group_list_repository_impl.dart';
import '../domain/institution_group_list.dart';
import '../domain/institution_group_list_query.dart';
import 'institution_group_list_state.dart';

final institutionGroupListControllerProvider =
    NotifierProvider.autoDispose<
      InstitutionGroupListController,
      InstitutionGroupListState
    >(InstitutionGroupListController.new);

final institutionGroupListRetainedQueryProvider =
    Provider<InstitutionGroupListRetainedQueryStore>((ref) {
      final store = InstitutionGroupListRetainedQueryStore();

      ref.listen(authSessionControllerProvider, (_, next) {
        store.clearUnlessMatches(
          InstitutionGroupListSessionSnapshot.fromSession(
            next,
            AppDeviceSurface.desktop,
          ).eligibleKey,
        );
      });
      ref.listen(appDeviceSurfaceProvider, (_, next) {
        if (next != AppDeviceSurface.desktop) {
          store.clear();
        }
      });

      return store;
    });

const institutionGroupCreateRecoveryWarning =
    'Creation result remains unconfirmed. Review recent active groups before creating another group.';

class InstitutionGroupListController
    extends Notifier<InstitutionGroupListState> {
  InstitutionGroupListSessionKey? _activeSessionKey;
  InstitutionGroupListQuery? _inFlightQuery;
  Timer? _searchDebounce;
  int _operationGeneration = 0;
  String? _recoveryWarning;
  var _authoritativeRowsStale = false;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  InstitutionGroupListState build() {
    _isDisposed = false;
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() {
        _isDisposed = true;
        _searchDebounce?.cancel();
        _invalidateOperations();
      });
    }

    final session = ref.watch(authSessionControllerProvider);
    final surface = ref.watch(appDeviceSurfaceProvider);
    final sessionKey = InstitutionGroupListSessionSnapshot.fromSession(
      session,
      surface,
    ).eligibleKey;

    if (sessionKey == null) {
      _clearActiveSession();

      return const InstitutionGroupListState.initial();
    }

    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _searchDebounce?.cancel();
    _invalidateOperations();
    _activeSessionKey = sessionKey;
    final retainedStore = ref.read(institutionGroupListRetainedQueryProvider);
    retainedStore.clearUnlessMatches(sessionKey);
    final retained = retainedStore.value;
    final query = retained?.matches(sessionKey) ?? false
        ? retained!.query
        : const InstitutionGroupListQuery.initial();
    final searchDraft = retained?.matches(sessionKey) ?? false
        ? retained!.searchDraft
        : query.search ?? '';
    _authoritativeRowsStale =
        retained?.matches(sessionKey) == true &&
        retained!.authoritativeRowsStale;
    _recoveryWarning =
        retained?.matches(sessionKey) == true &&
            retained!.recoveryWarningPending
        ? institutionGroupCreateRecoveryWarning
        : null;
    if (_recoveryWarning != null) {
      retainedStore.consumeRecoveryWarning(sessionKey);
    }

    scheduleMicrotask(() {
      if (_matchesSession(sessionKey)) {
        _startLogicalLoad(
          query,
          searchDraft: searchDraft,
          presentation: _LoadPresentation.initial,
        );
      }
    });

    return InstitutionGroupListState.loading(
      query: query,
      searchDraft: searchDraft,
      recoveryWarning: _recoveryWarning,
    );
  }

  void updateSearchDraft(String value) {
    final isValid = InstitutionGroupListQuery.isSearchInputValid(value);
    _searchDebounce?.cancel();
    state = state.withSearchDraft(
      value,
      errorText: isValid ? null : 'Search must be 254 characters or fewer.',
    );
    _rememberQuery();

    if (!isValid) {
      return;
    }

    _searchDebounce = Timer(
      InstitutionGroupListQuery.searchDebounceDuration,
      commitSearchNow,
    );
  }

  void commitSearchNow() {
    _searchDebounce?.cancel();
    if (!_hasValidSearchDraft()) {
      return;
    }

    _commitQuery(
      state.query.withSearch(
        InstitutionGroupListQuery.normalizeSearch(state.searchDraft),
      ),
    );
  }

  void setStatus(InstitutionGroupStatusFilter? status) {
    final base = _queryWithCommittedDraft();
    if (base == null) {
      return;
    }

    _commitQuery(base.withStatus(status));
  }

  void toggleSort(InstitutionGroupListSort sort) {
    final base = _queryWithCommittedDraft();
    if (base == null) {
      return;
    }

    _commitQuery(base.withSort(sort));
  }

  void setPerPage(int perPage) {
    final base = _queryWithCommittedDraft();
    if (base == null) {
      return;
    }

    _commitQuery(base.withPerPage(perPage));
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
      return;
    }
    if (!state.canGoPrevious) {
      return;
    }

    _commitQuery(state.query.withPage(state.query.page - 1));
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
      return;
    }
    if (!state.canGoNext) {
      return;
    }

    _commitQuery(state.query.withPage(state.query.page + 1));
  }

  void returnToFirstPage() {
    if (!_hasValidSearchDraft() || state.isRequestInFlight) {
      return;
    }

    final pending = _queryWithCommittedDraft();
    if (pending == null) {
      return;
    }
    if (pending.search != state.query.search) {
      _commitQuery(pending);
      return;
    }
    if (state.query.page == InstitutionGroupListQuery.initialPage) {
      return;
    }

    _commitQuery(state.query.withPage(InstitutionGroupListQuery.initialPage));
  }

  void clearFilters() {
    _searchDebounce?.cancel();
    final query = state.query.clearSearchAndStatus();
    final shouldLoad = query != state.query;
    state = state.withSearchDraft('');
    _rememberQuery();

    if (shouldLoad) {
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
    final presentation = query == state.query && state.result != null
        ? _LoadPresentation.refresh
        : _LoadPresentation.query;
    _startLogicalLoad(
      query,
      searchDraft: state.searchDraft,
      presentation: presentation,
    );
  }

  void retry() {
    if (state.status != InstitutionGroupListStatus.error ||
        state.isRetryInFlight ||
        _inFlightQuery != null) {
      return;
    }

    _searchDebounce?.cancel();
    _startLogicalLoad(
      state.query,
      searchDraft: state.searchDraft,
      presentation: _LoadPresentation.retry,
    );
  }

  InstitutionGroupListQuery? _queryWithCommittedDraft() {
    _searchDebounce?.cancel();
    if (!_hasValidSearchDraft()) {
      return null;
    }

    final normalized = InstitutionGroupListQuery.normalizeSearch(
      state.searchDraft,
    );

    return normalized == state.query.search
        ? state.query
        : state.query.withSearch(normalized);
  }

  bool _hasValidSearchDraft() {
    if (InstitutionGroupListQuery.isSearchInputValid(state.searchDraft)) {
      return true;
    }

    state = state.withSearchDraft(
      state.searchDraft,
      errorText: 'Search must be 254 characters or fewer.',
    );
    _rememberQuery();

    return false;
  }

  void _commitQuery(InstitutionGroupListQuery query, {String? searchDraft}) {
    final nextDraft = searchDraft ?? state.searchDraft;
    if (query == state.query) {
      if (nextDraft != state.searchDraft || state.searchErrorText != null) {
        state = state.withSearchDraft(nextDraft);
        _rememberQuery();
      }
      return;
    }

    _startLogicalLoad(
      query,
      searchDraft: nextDraft,
      presentation: _LoadPresentation.query,
    );
  }

  void _startLogicalLoad(
    InstitutionGroupListQuery query, {
    required String searchDraft,
    required _LoadPresentation presentation,
  }) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        !_matchesSession(sessionKey) ||
        (_inFlightQuery == query && state.isRequestInFlight)) {
      return;
    }

    _operationGeneration += 1;
    final generation = _operationGeneration;
    _inFlightQuery = query;
    state = switch (presentation) {
      _LoadPresentation.initial => InstitutionGroupListState.loading(
        query: query,
        searchDraft: searchDraft,
        recoveryWarning: _recoveryWarning,
      ),
      _LoadPresentation.query => InstitutionGroupListState.queryLoading(
        query: query,
        searchDraft: searchDraft,
        recoveryWarning: _recoveryWarning,
      ),
      _LoadPresentation.refresh => InstitutionGroupListState.refreshing(
        query: query,
        searchDraft: searchDraft,
        result: state.result!,
        recoveryWarning: _recoveryWarning,
      ),
      _LoadPresentation.retry => state.retrying(),
    };
    _rememberQuery();
    unawaited(
      _load(
        query,
        sessionKey: sessionKey,
        generation: generation,
        correctionUsed: false,
      ),
    );
  }

  Future<void> _load(
    InstitutionGroupListQuery query, {
    required InstitutionGroupListSessionKey sessionKey,
    required int generation,
    required bool correctionUsed,
  }) async {
    try {
      final result = await ref
          .read(institutionGroupListRepositoryProvider)
          .fetchGroups(query);
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }

      final correctionTarget = _correctionTarget(
        query,
        result,
        correctionUsed: correctionUsed,
      );
      if (correctionTarget != null) {
        final correctedQuery = query.withPage(correctionTarget);
        _inFlightQuery = correctedQuery;
        state = InstitutionGroupListState.queryLoading(
          query: correctedQuery,
          searchDraft: state.searchDraft,
          recoveryWarning: _recoveryWarning,
        );
        _rememberQuery();
        await _load(
          correctedQuery,
          sessionKey: sessionKey,
          generation: generation,
          correctionUsed: true,
        );
        return;
      }

      state = InstitutionGroupListState.fromResult(
        query: query,
        searchDraft: state.searchDraft,
        result: result,
        recoveryWarning: _recoveryWarning,
      );
      _authoritativeRowsStale = false;
      _rememberQuery();
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }

      state = InstitutionGroupListState.error(
        query: query,
        searchDraft: state.searchDraft,
        failure: exception.failure,
        recoveryWarning: _recoveryWarning,
      );
    } catch (_) {
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }

      state = InstitutionGroupListState.error(
        query: query,
        searchDraft: state.searchDraft,
        failure: ApiFailure.local(
          kind: ApiFailureKind.unknown,
          message: 'Unexpected Institution Group list failure.',
        ),
        recoveryWarning: _recoveryWarning,
      );
    } finally {
      if (generation == _operationGeneration && _inFlightQuery == query) {
        _inFlightQuery = null;
      }
    }
  }

  int? _correctionTarget(
    InstitutionGroupListQuery query,
    InstitutionGroupListPage result, {
    required bool correctionUsed,
  }) {
    if (correctionUsed || result.groups.isNotEmpty || query.page <= 1) {
      return null;
    }

    final target = result.pagination.total == 0
        ? 1
        : math.max(1, math.min(result.pagination.lastPage, query.page - 1));

    return target == query.page ? null : target;
  }

  bool _canPublish(
    int generation,
    InstitutionGroupListSessionKey sessionKey,
    InstitutionGroupListQuery query,
  ) {
    return !_isDisposed &&
        generation == _operationGeneration &&
        _inFlightQuery == query &&
        state.query == query &&
        _matchesSession(sessionKey);
  }

  bool _matchesSession(InstitutionGroupListSessionKey key) {
    return !_isDisposed &&
        _activeSessionKey == key &&
        InstitutionGroupListSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            key;
  }

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }

    _clearActiveSession();
    state = const InstitutionGroupListState.initial();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }

    return true;
  }

  void _clearActiveSession() {
    ref
        .read(institutionGroupListRetainedQueryProvider)
        .clearIfMatches(_activeSessionKey);
    _activeSessionKey = null;
    _recoveryWarning = null;
    _authoritativeRowsStale = false;
    _searchDebounce?.cancel();
    _invalidateOperations();
  }

  void _invalidateOperations() {
    _operationGeneration += 1;
    _inFlightQuery = null;
  }

  void _rememberQuery() {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null) {
      return;
    }

    ref
        .read(institutionGroupListRetainedQueryProvider)
        .value = InstitutionGroupListRetainedQuery(
      sessionKey: sessionKey,
      query: state.query,
      searchDraft: state.searchDraft,
      authoritativeRowsStale: _authoritativeRowsStale,
      recoveryWarningPending: false,
    );
  }
}

class InstitutionGroupListSessionSnapshot {
  const InstitutionGroupListSessionSnapshot({
    required this.status,
    required this.userId,
    required this.userInstance,
    required this.userInstitutionId,
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
    required this.institutionId,
    required this.institutionStatus,
    required this.surface,
  });

  factory InstitutionGroupListSessionSnapshot.fromSession(
    AuthSessionState session,
    AppDeviceSurface surface,
  ) {
    final user = session.user;
    final institution = user?.institution;

    return InstitutionGroupListSessionSnapshot(
      status: session.status,
      userId: user?.id,
      userInstance: user,
      userInstitutionId: user?.institutionId,
      role: user?.role,
      isActive: user?.isActive,
      mustChangePassword: user?.mustChangePassword,
      institutionId: institution?.id,
      institutionStatus: institution?.status,
      surface: surface,
    );
  }

  final AuthSessionStatus status;
  final String? userId;
  final Object? userInstance;
  final String? userInstitutionId;
  final UserRole? role;
  final bool? isActive;
  final bool? mustChangePassword;
  final String? institutionId;
  final String? institutionStatus;
  final AppDeviceSurface surface;

  InstitutionGroupListSessionKey? get eligibleKey {
    final currentUserId = userId;
    final currentUserInstance = userInstance;
    final currentInstitutionId = userInstitutionId;
    if (status != AuthSessionStatus.authenticated ||
        currentUserId == null ||
        currentUserInstance == null ||
        role != UserRole.institutionAdmin ||
        isActive != true ||
        mustChangePassword != false ||
        currentInstitutionId == null ||
        currentInstitutionId.trim().isEmpty ||
        institutionId != currentInstitutionId ||
        institutionStatus != 'active' ||
        surface != AppDeviceSurface.desktop) {
      return null;
    }

    return InstitutionGroupListSessionKey(
      userId: currentUserId,
      userInstance: currentUserInstance,
      institutionId: currentInstitutionId,
    );
  }
}

class InstitutionGroupListSessionKey {
  const InstitutionGroupListSessionKey({
    required this.userId,
    required this.userInstance,
    required this.institutionId,
  });

  final String userId;
  final Object userInstance;
  final String institutionId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstitutionGroupListSessionKey &&
            other.userId == userId &&
            identical(other.userInstance, userInstance) &&
            other.institutionId == institutionId;
  }

  @override
  int get hashCode =>
      Object.hash(userId, identityHashCode(userInstance), institutionId);
}

class InstitutionGroupListRetainedQueryStore {
  InstitutionGroupListRetainedQuery? value;

  void clear() {
    value = null;
  }

  void clearIfMatches(InstitutionGroupListSessionKey? key) {
    if (key != null && value?.matches(key) == true) {
      value = null;
    }
  }

  void clearUnlessMatches(InstitutionGroupListSessionKey? key) {
    if (key == null || value?.matches(key) != true) {
      value = null;
    }
  }

  void markAuthoritativeRowsStale(InstitutionGroupListSessionKey key) {
    final retained = value;
    value = retained?.matches(key) == true
        ? retained!.copyWith(authoritativeRowsStale: true)
        : InstitutionGroupListRetainedQuery(
            sessionKey: key,
            query: const InstitutionGroupListQuery.initial(),
            searchDraft: '',
            authoritativeRowsStale: true,
          );
  }

  void prepareUnknownCreateRecovery(InstitutionGroupListSessionKey key) {
    final retained = value;
    final retainedQuery = retained?.matches(key) == true
        ? retained!.query
        : const InstitutionGroupListQuery.initial();
    value = InstitutionGroupListRetainedQuery(
      sessionKey: key,
      query: retainedQuery.copyWith(
        search: null,
        status: InstitutionGroupStatusFilter.active,
        page: InstitutionGroupListQuery.initialPage,
        sort: InstitutionGroupListSort.createdAt,
        direction: InstitutionGroupSortDirection.desc,
      ),
      searchDraft: '',
      authoritativeRowsStale: true,
      recoveryWarningPending: true,
    );
  }

  void consumeRecoveryWarning(InstitutionGroupListSessionKey key) {
    final retained = value;
    if (retained?.matches(key) == true && retained!.recoveryWarningPending) {
      value = retained.copyWith(recoveryWarningPending: false);
    }
  }
}

class InstitutionGroupListRetainedQuery {
  const InstitutionGroupListRetainedQuery({
    required this.sessionKey,
    required this.query,
    required this.searchDraft,
    this.authoritativeRowsStale = false,
    this.recoveryWarningPending = false,
  });

  final InstitutionGroupListSessionKey sessionKey;
  final InstitutionGroupListQuery query;
  final String searchDraft;
  final bool authoritativeRowsStale;
  final bool recoveryWarningPending;

  bool matches(InstitutionGroupListSessionKey key) => sessionKey == key;

  InstitutionGroupListRetainedQuery copyWith({
    InstitutionGroupListQuery? query,
    String? searchDraft,
    bool? authoritativeRowsStale,
    bool? recoveryWarningPending,
  }) {
    return InstitutionGroupListRetainedQuery(
      sessionKey: sessionKey,
      query: query ?? this.query,
      searchDraft: searchDraft ?? this.searchDraft,
      authoritativeRowsStale:
          authoritativeRowsStale ?? this.authoritativeRowsStale,
      recoveryWarningPending:
          recoveryWarningPending ?? this.recoveryWarningPending,
    );
  }
}

enum _LoadPresentation { initial, query, refresh, retry }
