import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/institution_user_list_repository_impl.dart';
import '../domain/institution_group.dart';
import '../domain/institution_user.dart';
import '../domain/institution_user_list.dart';
import '../domain/institution_user_list_query.dart';
import 'institution_group_detail_controller.dart';
import 'institution_group_detail_state.dart';
import 'institution_group_membership_candidate_state.dart';
import 'institution_group_membership_list_controller.dart';

final institutionGroupMembershipCandidateControllerProvider = NotifierProvider
    .autoDispose
    .family<
      InstitutionGroupMembershipCandidateController,
      InstitutionGroupMembershipCandidateState,
      InstitutionGroupMembershipListKey
    >(InstitutionGroupMembershipCandidateController.new);

class InstitutionGroupMembershipCandidateController
    extends Notifier<InstitutionGroupMembershipCandidateState> {
  InstitutionGroupMembershipCandidateController(this.key);

  final InstitutionGroupMembershipListKey key;

  InstitutionGroupDetailSessionKey? _activeSessionKey;
  InstitutionGroup? _selectedGroup;
  InstitutionUserListQuery? _inFlightQuery;
  Timer? _searchDebounce;
  int _operationGeneration = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  InstitutionGroupMembershipCandidateState build() {
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
    final current =
        detail.status == InstitutionGroupDetailStatus.data ||
            detail.status == InstitutionGroupDetailStatus.refreshing
        ? detail.group
        : null;
    if (sessionKey == null ||
        current == null ||
        current.status != InstitutionGroupStatus.active ||
        current.id.toLowerCase() != key.groupId.toLowerCase()) {
      _clearOwnership();
      return const InstitutionGroupMembershipCandidateState.closed();
    }
    if (_activeSessionKey != sessionKey) {
      _clearOwnership();
      _activeSessionKey = sessionKey;
      return const InstitutionGroupMembershipCandidateState.closed();
    }
    if (_selectedGroup != null && !identical(_selectedGroup, current)) {
      _close();
      return const InstitutionGroupMembershipCandidateState.closed();
    }
    return state;
  }

  bool open(InstitutionGroup selected) {
    final sessionKey = _activeSessionKey;
    final detail = ref.read(
      institutionGroupDetailControllerProvider(key.groupId),
    );
    if (sessionKey == null ||
        state.isOpen ||
        detail.status != InstitutionGroupDetailStatus.data ||
        !identical(detail.group, selected) ||
        selected.status != InstitutionGroupStatus.active ||
        !_matchesSession(sessionKey)) {
      return false;
    }
    _selectedGroup = selected;
    final query = _fixedQuery();
    _startLoad(query, searchDraft: '', selected: const []);
    return true;
  }

  void close() {
    if (state.isRequestInFlight) {
      return;
    }
    _close();
    state = const InstitutionGroupMembershipCandidateState.closed();
  }

  void forceClose() {
    _close();
    state = const InstitutionGroupMembershipCandidateState.closed();
  }

  void updateSearchDraft(String value) {
    if (!state.isOpen) {
      return;
    }
    final valid = InstitutionUserListQuery.isSearchInputValid(value);
    _searchDebounce?.cancel();
    state = state.withSearchDraft(
      value,
      errorText: valid ? null : 'Search must be 254 characters or fewer.',
    );
    if (valid) {
      _searchDebounce = Timer(
        InstitutionUserListQuery.searchDebounceDuration,
        commitSearchNow,
      );
    }
  }

  void commitSearchNow() {
    _searchDebounce?.cancel();
    if (!_hasValidSearchDraft() || state.query == null) {
      return;
    }
    final query = state.query!.withSearch(
      InstitutionUserListQuery.normalizeSearch(state.searchDraft),
    );
    if (query != state.query) {
      _startLoad(
        query,
        searchDraft: state.searchDraft,
        selected: state.selected,
      );
    }
  }

  void previousPage() {
    if (state.isRequestInFlight || !_hasValidSearchDraft()) {
      return;
    }
    final pending = _queryWithCommittedDraft();
    if (pending == null) {
      return;
    }
    if (pending.search != state.query!.search) {
      _startLoad(
        pending,
        searchDraft: state.searchDraft,
        selected: state.selected,
      );
      return;
    }
    if (!state.canGoPrevious) {
      return;
    }
    final query = state.query!.withPage(state.query!.page - 1);
    _startLoad(query, searchDraft: state.searchDraft, selected: state.selected);
  }

  void nextPage() {
    if (state.isRequestInFlight || !_hasValidSearchDraft()) {
      return;
    }
    final pending = _queryWithCommittedDraft();
    if (pending == null) {
      return;
    }
    if (pending.search != state.query!.search) {
      _startLoad(
        pending,
        searchDraft: state.searchDraft,
        selected: state.selected,
      );
      return;
    }
    if (!state.canGoNext) {
      return;
    }
    final query = state.query!.withPage(state.query!.page + 1);
    _startLoad(query, searchDraft: state.searchDraft, selected: state.selected);
  }

  void retry() {
    if (state.status != InstitutionGroupMembershipCandidateStatus.error ||
        state.isRetryInFlight ||
        state.query == null ||
        _inFlightQuery != null) {
      return;
    }
    _startLoad(
      state.query!,
      searchDraft: state.searchDraft,
      selected: state.selected,
      retry: true,
    );
  }

  void toggleSelection(InstitutionUser user, bool selected) {
    if (state.isRequestInFlight || !state.isOpen) {
      return;
    }
    final currentPageOwns =
        state.result?.users.any((candidate) => identical(candidate, user)) ??
        false;
    if (!currentPageOwns ||
        user.role != key.kind.candidateRole ||
        !user.isActive) {
      return;
    }
    final next = <InstitutionUser>[...state.selected];
    final existing = next.indexWhere(
      (candidate) => candidate.id.toLowerCase() == user.id.toLowerCase(),
    );
    if (selected) {
      if (existing >= 0 || next.length >= 100) {
        return;
      }
      next.add(user);
    } else if (existing >= 0) {
      next.removeAt(existing);
    }
    state = state.withSelection(next);
  }

  void removeSelected(InstitutionUser user) {
    if (state.isRequestInFlight || !state.isOpen) {
      return;
    }
    final next = <InstitutionUser>[...state.selected]
      ..removeWhere(
        (candidate) => candidate.id.toLowerCase() == user.id.toLowerCase(),
      );
    state = state.withSelection(next);
  }

  InstitutionUserListQuery _fixedQuery() =>
      const InstitutionUserListQuery.initial().copyWith(
        role: key.kind.candidateRole,
        status: InstitutionUserStatusFilter.active,
        page: 1,
        perPage: 20,
        sort: InstitutionUserListSort.fullName,
        direction: InstitutionUserSortDirection.asc,
      );

  InstitutionUserListQuery? _queryWithCommittedDraft() {
    _searchDebounce?.cancel();
    if (!_hasValidSearchDraft() || state.query == null) {
      return null;
    }
    final normalized = InstitutionUserListQuery.normalizeSearch(
      state.searchDraft,
    );
    return normalized == state.query!.search
        ? state.query
        : state.query!.withSearch(normalized);
  }

  bool _hasValidSearchDraft() {
    if (InstitutionUserListQuery.isSearchInputValid(state.searchDraft)) {
      return true;
    }
    state = state.withSearchDraft(
      state.searchDraft,
      errorText: 'Search must be 254 characters or fewer.',
    );
    return false;
  }

  void _startLoad(
    InstitutionUserListQuery query, {
    required String searchDraft,
    required List<InstitutionUser> selected,
    bool retry = false,
  }) {
    final sessionKey = _activeSessionKey;
    final group = _selectedGroup;
    if (sessionKey == null ||
        group == null ||
        !_canOwn(group, sessionKey) ||
        (_inFlightQuery == query && state.isRequestInFlight)) {
      return;
    }
    final generation = ++_operationGeneration;
    _inFlightQuery = query;
    state = retry
        ? state.retrying()
        : InstitutionGroupMembershipCandidateState.loading(
            group: group,
            query: query,
            searchDraft: searchDraft,
            selected: List.unmodifiable(selected),
          );
    unawaited(
      _load(
        query,
        group: group,
        sessionKey: sessionKey,
        generation: generation,
        correctionUsed: false,
      ),
    );
  }

  Future<void> _load(
    InstitutionUserListQuery query, {
    required InstitutionGroup group,
    required InstitutionGroupDetailSessionKey sessionKey,
    required int generation,
    required bool correctionUsed,
  }) async {
    try {
      final result = await ref
          .read(institutionUserListRepositoryProvider)
          .fetchUsers(query);
      if (!_canPublish(generation, sessionKey, group, query)) {
        return;
      }
      _validatePurpose(result);
      final correction = _correctionTarget(
        query,
        result,
        correctionUsed: correctionUsed,
      );
      if (correction != null) {
        final corrected = query.withPage(correction);
        _inFlightQuery = corrected;
        state = InstitutionGroupMembershipCandidateState.loading(
          group: group,
          query: corrected,
          searchDraft: state.searchDraft,
          selected: state.selected,
        );
        await _load(
          corrected,
          group: group,
          sessionKey: sessionKey,
          generation: generation,
          correctionUsed: true,
        );
        return;
      }
      state = InstitutionGroupMembershipCandidateState.fromResult(
        group: group,
        query: query,
        searchDraft: state.searchDraft,
        result: result,
        selected: state.selected,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey, group, query)) {
        return;
      }
      if (_isSessionFailure(exception.failure)) {
        _clearOwnership();
        state = const InstitutionGroupMembershipCandidateState.closed();
        if (exception.failure.serverCode !=
            ApiErrorCodes.authenticationRequired) {
          unawaited(
            ref.read(authSessionControllerProvider.notifier).bootstrap(),
          );
        }
        return;
      }
      state = InstitutionGroupMembershipCandidateState.error(
        group: group,
        query: query,
        searchDraft: state.searchDraft,
        failure: exception.failure,
        selected: state.selected,
      );
    } catch (_) {
      if (_canPublish(generation, sessionKey, group, query)) {
        state = InstitutionGroupMembershipCandidateState.error(
          group: group,
          query: query,
          searchDraft: state.searchDraft,
          failure: ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Candidate users could not be loaded safely.',
          ),
          selected: state.selected,
        );
      }
    } finally {
      if (generation == _operationGeneration && _inFlightQuery == query) {
        _inFlightQuery = null;
      }
    }
  }

  void _validatePurpose(InstitutionUserListPage result) {
    final ids = <String>{};
    for (final user in result.users) {
      if (user.role != key.kind.candidateRole ||
          !user.isActive ||
          !ids.add(user.id.toLowerCase())) {
        throw ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            message: 'Candidate page did not match its fixed purpose.',
          ),
        );
      }
    }
  }

  int? _correctionTarget(
    InstitutionUserListQuery query,
    InstitutionUserListPage result, {
    required bool correctionUsed,
  }) {
    if (correctionUsed || result.users.isNotEmpty || query.page <= 1) {
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
    InstitutionGroup group,
    InstitutionUserListQuery query,
  ) =>
      !_isDisposed &&
      generation == _operationGeneration &&
      _inFlightQuery == query &&
      identical(_selectedGroup, group) &&
      _matchesSession(sessionKey) &&
      _canOwn(group, sessionKey);

  bool _canOwn(
    InstitutionGroup group,
    InstitutionGroupDetailSessionKey sessionKey,
  ) {
    final detail = ref.read(
      institutionGroupDetailControllerProvider(key.groupId),
    );
    return _matchesSession(sessionKey) &&
        (detail.status == InstitutionGroupDetailStatus.data ||
            detail.status == InstitutionGroupDetailStatus.refreshing) &&
        identical(detail.group, group) &&
        group.status == InstitutionGroupStatus.active;
  }

  bool _matchesSession(InstitutionGroupDetailSessionKey sessionKey) =>
      !_isDisposed &&
      _activeSessionKey == sessionKey &&
      InstitutionGroupDetailSessionSnapshot.fromSession(
            ref.read(authSessionControllerProvider),
            ref.read(appDeviceSurfaceProvider),
          ).eligibleKey ==
          sessionKey;

  bool _isSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    return code == ApiErrorCodes.authenticationRequired ||
        code == ApiErrorCodes.passwordChangeRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive;
  }

  void _close() {
    _selectedGroup = null;
    _searchDebounce?.cancel();
    _invalidateOperations();
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _close();
  }

  void _invalidateOperations() {
    _operationGeneration += 1;
    _inFlightQuery = null;
  }
}
