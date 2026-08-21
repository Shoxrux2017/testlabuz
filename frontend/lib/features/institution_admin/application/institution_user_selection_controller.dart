import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/institution_user_list_repository_impl.dart';
import '../domain/institution_user.dart';
import '../domain/institution_user_list.dart';
import '../domain/institution_user_list_query.dart';
import '../domain/institution_user_selection.dart';
import 'institution_parent_student_relationship_list_controller.dart';
import 'institution_user_selection_state.dart';

final institutionUserSelectionControllerProvider = NotifierProvider.autoDispose
    .family<
      InstitutionUserSelectionController,
      InstitutionUserSelectionState,
      InstitutionUserSelectionPurpose
    >(InstitutionUserSelectionController.new);

class InstitutionUserSelectionController
    extends Notifier<InstitutionUserSelectionState> {
  InstitutionUserSelectionController(this.purpose);

  final InstitutionUserSelectionPurpose purpose;

  InstitutionParentStudentSessionKey? _activeSessionKey;
  InstitutionUserListQuery? _inFlightQuery;
  Timer? _searchDebounce;
  int _operationGeneration = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  InstitutionUserSelectionState build() {
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
      return InstitutionUserSelectionState.closed(purpose: purpose);
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }
    _clearOwnership();
    _activeSessionKey = sessionKey;
    return InstitutionUserSelectionState.closed(purpose: purpose);
  }

  bool open({InstitutionUser? selected}) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null || state.isOpen || !_matchesSession(sessionKey)) {
      return false;
    }
    final query = purpose.fixedQuery();
    _startLoad(query, searchDraft: '', selected: selected);
    return true;
  }

  void close() {
    _searchDebounce?.cancel();
    _invalidateOperations();
    state = InstitutionUserSelectionState.closed(purpose: purpose);
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
    if (state.canGoPrevious) {
      _startLoad(
        state.query!.withPage(state.query!.page - 1),
        searchDraft: state.searchDraft,
        selected: state.selected,
      );
    }
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
    if (state.canGoNext) {
      _startLoad(
        state.query!.withPage(state.query!.page + 1),
        searchDraft: state.searchDraft,
        selected: state.selected,
      );
    }
  }

  void retry() {
    if (state.status != InstitutionUserSelectionStatus.error ||
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

  void select(InstitutionUser? user) {
    if (state.isRequestInFlight || !state.isOpen) {
      return;
    }
    if (user != null) {
      final owned =
          state.result?.users.any((candidate) => identical(candidate, user)) ??
          false;
      if (!owned || !_matchesPurpose(user)) {
        return;
      }
    }
    state = state.withSelection(user);
  }

  bool ownsSelected(InstitutionUser user) =>
      state.isOpen && identical(state.selected, user) && _matchesPurpose(user);

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
    required InstitutionUser? selected,
    bool retry = false,
  }) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        !_matchesSession(sessionKey) ||
        (_inFlightQuery == query && state.isRequestInFlight)) {
      return;
    }
    final generation = ++_operationGeneration;
    _inFlightQuery = query;
    state = retry
        ? state.retrying()
        : InstitutionUserSelectionState.loading(
            purpose: purpose,
            query: query,
            searchDraft: searchDraft,
            selected: selected,
          );
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
    InstitutionUserListQuery query, {
    required InstitutionParentStudentSessionKey sessionKey,
    required int generation,
    required bool correctionUsed,
  }) async {
    try {
      final result = await ref
          .read(institutionUserListRepositoryProvider)
          .fetchUsers(query);
      if (!_canPublish(generation, sessionKey, query)) {
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
        state = InstitutionUserSelectionState.loading(
          purpose: purpose,
          query: corrected,
          searchDraft: state.searchDraft,
          selected: state.selected,
        );
        await _load(
          corrected,
          sessionKey: sessionKey,
          generation: generation,
          correctionUsed: true,
        );
        return;
      }
      state = InstitutionUserSelectionState.fromResult(
        purpose: purpose,
        query: query,
        searchDraft: state.searchDraft,
        result: result,
        selected: state.selected,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }
      if (_isSessionFailure(exception.failure)) {
        _clearOwnership();
        state = InstitutionUserSelectionState.closed(purpose: purpose);
        if (exception.failure.serverCode !=
            ApiErrorCodes.authenticationRequired) {
          unawaited(
            ref.read(authSessionControllerProvider.notifier).bootstrap(),
          );
        }
        return;
      }
      state = InstitutionUserSelectionState.error(
        purpose: purpose,
        query: query,
        searchDraft: state.searchDraft,
        failure: exception.failure,
        selected: state.selected,
      );
    } catch (_) {
      if (_canPublish(generation, sessionKey, query)) {
        state = InstitutionUserSelectionState.error(
          purpose: purpose,
          query: query,
          searchDraft: state.searchDraft,
          failure: ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'User choices could not be loaded safely.',
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
      if (!_matchesPurpose(user) || !ids.add(user.id.toLowerCase())) {
        throw ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            message: 'User selection page did not match its fixed purpose.',
          ),
        );
      }
    }
  }

  bool _matchesPurpose(InstitutionUser user) =>
      user.role == purpose.role && (!purpose.activeOnly || user.isActive);

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
    InstitutionParentStudentSessionKey sessionKey,
    InstitutionUserListQuery query,
  ) =>
      !_isDisposed &&
      generation == _operationGeneration &&
      _inFlightQuery == query &&
      _matchesSession(sessionKey);

  bool _matchesSession(InstitutionParentStudentSessionKey sessionKey) =>
      !_isDisposed &&
      _activeSessionKey == sessionKey &&
      InstitutionParentStudentSessionSnapshot.fromSession(
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

  void _clearOwnership() {
    _activeSessionKey = null;
    _searchDebounce?.cancel();
    _invalidateOperations();
  }

  void _invalidateOperations() {
    _operationGeneration += 1;
    _inFlightQuery = null;
  }
}
