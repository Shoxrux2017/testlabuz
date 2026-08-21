import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/dto/institution_group_dto.dart';
import '../data/institution_group_membership_repository_impl.dart';
import '../domain/institution_group_membership.dart';
import '../domain/institution_group_membership_list.dart';
import '../domain/institution_group_membership_query.dart';
import 'institution_group_detail_controller.dart';
import 'institution_group_detail_state.dart';
import 'institution_group_membership_list_state.dart';

final institutionGroupMembershipListControllerProvider = NotifierProvider
    .autoDispose
    .family<
      InstitutionGroupMembershipListController,
      InstitutionGroupMembershipListState,
      InstitutionGroupMembershipListKey
    >(InstitutionGroupMembershipListController.new);

class InstitutionGroupMembershipListKey {
  const InstitutionGroupMembershipListKey({
    required this.groupId,
    required this.kind,
  });

  final String groupId;
  final InstitutionGroupMemberKind kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstitutionGroupMembershipListKey &&
          other.groupId.toLowerCase() == groupId.toLowerCase() &&
          other.kind == kind;

  @override
  int get hashCode => Object.hash(groupId.toLowerCase(), kind);
}

class InstitutionGroupMembershipListController
    extends Notifier<InstitutionGroupMembershipListState> {
  InstitutionGroupMembershipListController(this.key);

  final InstitutionGroupMembershipListKey key;

  InstitutionGroupDetailSessionKey? _activeSessionKey;
  InstitutionGroupMembershipQuery? _inFlightQuery;
  Timer? _searchDebounce;
  int _operationGeneration = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  InstitutionGroupMembershipListState build() {
    _isDisposed = false;
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() {
        _isDisposed = true;
        _searchDebounce?.cancel();
        _invalidateOperations();
      });
    }
    final sessionKey = InstitutionGroupDetailSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final detail = ref.watch(
      institutionGroupDetailControllerProvider(key.groupId),
    );
    final hasConfirmedTarget =
        isCanonicalInstitutionGroupId(key.groupId) &&
        (detail.status == InstitutionGroupDetailStatus.data ||
            detail.status == InstitutionGroupDetailStatus.refreshing) &&
        detail.group?.id.toLowerCase() == key.groupId.toLowerCase();

    if (sessionKey == null || !hasConfirmedTarget) {
      _clearActiveSession();
      return const InstitutionGroupMembershipListState.initial();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _searchDebounce?.cancel();
    _invalidateOperations();
    _activeSessionKey = sessionKey;
    const query = InstitutionGroupMembershipQuery.initial();
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey) && _hasConfirmedDetailTarget()) {
        _startLogicalLoad(
          query,
          searchDraft: '',
          presentation: _MembershipLoadPresentation.initial,
        );
      }
    });
    return const InstitutionGroupMembershipListState.loading(
      query: query,
      searchDraft: '',
    );
  }

  void updateSearchDraft(String value) {
    final valid = InstitutionGroupMembershipQuery.isSearchInputValid(value);
    _searchDebounce?.cancel();
    state = state.withSearchDraft(
      value,
      errorText: valid ? null : 'Search must be 254 characters or fewer.',
    );
    if (valid) {
      _searchDebounce = Timer(
        InstitutionGroupMembershipQuery.searchDebounceDuration,
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
        InstitutionGroupMembershipQuery.normalizeSearch(state.searchDraft),
      ),
    );
  }

  void setStatus(InstitutionGroupMembershipStatusFilter? status) {
    final base = _queryWithCommittedDraft();
    if (base != null) {
      _commitQuery(base.withStatus(status));
    }
  }

  void toggleSort(InstitutionGroupMembershipSort sort) {
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
    _searchDebounce?.cancel();
    final query = state.query.clearSearchAndStatus();
    final shouldLoad = query != state.query;
    state = state.withSearchDraft('');
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
    _startLogicalLoad(
      query,
      searchDraft: state.searchDraft,
      presentation: query == state.query && state.result != null
          ? _MembershipLoadPresentation.refresh
          : _MembershipLoadPresentation.query,
    );
  }

  void retry() {
    if (state.status != InstitutionGroupMembershipListStatus.error ||
        state.isRetryInFlight ||
        _inFlightQuery != null) {
      return;
    }
    _searchDebounce?.cancel();
    _startLogicalLoad(
      state.query,
      searchDraft: state.searchDraft,
      presentation: _MembershipLoadPresentation.retry,
    );
  }

  void markCheckingAndReload() {
    if (_activeSessionKey == null || !_hasConfirmedDetailTarget()) {
      return;
    }
    _searchDebounce?.cancel();
    _startLogicalLoad(
      state.query,
      searchDraft: state.searchDraft,
      presentation: _MembershipLoadPresentation.checking,
    );
  }

  bool ownsCurrentMembership(InstitutionGroupMembershipIdentity identity) {
    if (identity.groupId.toLowerCase() != key.groupId.toLowerCase() ||
        identity.kind != key.kind ||
        state.status != InstitutionGroupMembershipListStatus.data) {
      return false;
    }
    return state.result?.memberships.any(
          (membership) => identity.matches(
            currentGroupId: key.groupId,
            currentKind: key.kind,
            currentMembership: membership,
          ),
        ) ??
        false;
  }

  InstitutionGroupMembershipQuery? _queryWithCommittedDraft() {
    _searchDebounce?.cancel();
    if (!_hasValidSearchDraft()) {
      return null;
    }
    final normalized = InstitutionGroupMembershipQuery.normalizeSearch(
      state.searchDraft,
    );
    return normalized == state.query.search
        ? state.query
        : state.query.withSearch(normalized);
  }

  bool _hasValidSearchDraft() {
    if (InstitutionGroupMembershipQuery.isSearchInputValid(state.searchDraft)) {
      return true;
    }
    state = state.withSearchDraft(
      state.searchDraft,
      errorText: 'Search must be 254 characters or fewer.',
    );
    return false;
  }

  void _commitQuery(
    InstitutionGroupMembershipQuery query, {
    String? searchDraft,
  }) {
    final nextDraft = searchDraft ?? state.searchDraft;
    if (query == state.query) {
      if (nextDraft != state.searchDraft || state.searchErrorText != null) {
        state = state.withSearchDraft(nextDraft);
      }
      return;
    }
    _startLogicalLoad(
      query,
      searchDraft: nextDraft,
      presentation: _MembershipLoadPresentation.query,
    );
  }

  void _startLogicalLoad(
    InstitutionGroupMembershipQuery query, {
    required String searchDraft,
    required _MembershipLoadPresentation presentation,
  }) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        !_matchesSession(sessionKey) ||
        !_hasConfirmedDetailTarget() ||
        (_inFlightQuery == query && state.isRequestInFlight)) {
      return;
    }
    final generation = ++_operationGeneration;
    _inFlightQuery = query;
    state = switch (presentation) {
      _MembershipLoadPresentation.initial =>
        InstitutionGroupMembershipListState.loading(
          query: query,
          searchDraft: searchDraft,
        ),
      _MembershipLoadPresentation.query =>
        InstitutionGroupMembershipListState.loading(
          query: query,
          searchDraft: searchDraft,
          status: InstitutionGroupMembershipListStatus.queryLoading,
        ),
      _MembershipLoadPresentation.refresh =>
        InstitutionGroupMembershipListState.refreshing(
          query: query,
          searchDraft: searchDraft,
          result: state.result!,
        ),
      _MembershipLoadPresentation.retry => state.retrying(),
      _MembershipLoadPresentation.checking =>
        InstitutionGroupMembershipListState.checkingCurrentState(
          query: query,
          searchDraft: searchDraft,
          result: state.result,
        ),
    };
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
    InstitutionGroupMembershipQuery query, {
    required InstitutionGroupDetailSessionKey sessionKey,
    required int generation,
    required bool correctionUsed,
  }) async {
    try {
      final result = await ref
          .read(institutionGroupMembershipRepositoryProvider)
          .fetchMemberships(groupId: key.groupId, kind: key.kind, query: query);
      if (!_canPublish(generation, sessionKey, query)) {
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
        state = InstitutionGroupMembershipListState.loading(
          query: corrected,
          searchDraft: state.searchDraft,
          status: InstitutionGroupMembershipListStatus.queryLoading,
        );
        await _load(
          corrected,
          sessionKey: sessionKey,
          generation: generation,
          correctionUsed: true,
        );
        return;
      }
      state = InstitutionGroupMembershipListState.fromResult(
        query: query,
        searchDraft: state.searchDraft,
        result: result,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      state = InstitutionGroupMembershipListState.error(
        query: query,
        searchDraft: state.searchDraft,
        failure: exception.failure,
      );
      if (_isNotFound(exception.failure)) {
        ref
            .read(
              institutionGroupDetailControllerProvider(key.groupId).notifier,
            )
            .refresh();
      }
    } catch (_) {
      if (_canPublish(generation, sessionKey, query)) {
        state = InstitutionGroupMembershipListState.error(
          query: query,
          searchDraft: state.searchDraft,
          failure: ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Institution Group membership list failure.',
          ),
        );
      }
    } finally {
      if (generation == _operationGeneration && _inFlightQuery == query) {
        _inFlightQuery = null;
      }
    }
  }

  int? _correctionTarget(
    InstitutionGroupMembershipQuery query,
    InstitutionGroupMembershipListPage result, {
    required bool correctionUsed,
  }) {
    if (correctionUsed ||
        result.memberships.isNotEmpty ||
        query.page <= InstitutionGroupMembershipQuery.initialPage) {
      return null;
    }
    final target = result.pagination.total == 0
        ? 1
        : math.max(1, math.min(result.pagination.lastPage, query.page - 1));
    return target == query.page ? null : target;
  }

  bool _canPublish(
    int generation,
    InstitutionGroupDetailSessionKey sessionKey,
    InstitutionGroupMembershipQuery query,
  ) =>
      !_isDisposed &&
      generation == _operationGeneration &&
      _inFlightQuery == query &&
      state.query == query &&
      _matchesSession(sessionKey) &&
      _hasConfirmedDetailTarget();

  bool _matchesSession(InstitutionGroupDetailSessionKey sessionKey) =>
      !_isDisposed &&
      _activeSessionKey == sessionKey &&
      InstitutionGroupDetailSessionSnapshot.fromSession(
            ref.read(authSessionControllerProvider),
            ref.read(appDeviceSurfaceProvider),
          ).eligibleKey ==
          sessionKey;

  bool _hasConfirmedDetailTarget() {
    final detail = ref.read(
      institutionGroupDetailControllerProvider(key.groupId),
    );
    return (detail.status == InstitutionGroupDetailStatus.data ||
            detail.status == InstitutionGroupDetailStatus.refreshing) &&
        detail.group?.id.toLowerCase() == key.groupId.toLowerCase();
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
    state = const InstitutionGroupMembershipListState.initial();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  bool _isNotFound(ApiFailure failure) =>
      failure.statusCode == 404 &&
      failure.serverCode == ApiErrorCodes.resourceNotFound;

  void _clearActiveSession() {
    _activeSessionKey = null;
    _searchDebounce?.cancel();
    _invalidateOperations();
  }

  void _invalidateOperations() {
    _operationGeneration += 1;
    _inFlightQuery = null;
  }
}

enum _MembershipLoadPresentation { initial, query, refresh, retry, checking }
