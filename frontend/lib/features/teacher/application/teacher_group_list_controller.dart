import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_group_list_repository_impl.dart';
import '../domain/teacher_group_list.dart';
import '../domain/teacher_group_list_query.dart';
import 'teacher_group_list_state.dart';
import 'teacher_session_key.dart';

final teacherGroupListControllerProvider =
    NotifierProvider.autoDispose<
      TeacherGroupListController,
      TeacherGroupListState
    >(TeacherGroupListController.new);

class TeacherGroupListController extends Notifier<TeacherGroupListState> {
  TeacherSessionKey? _activeSessionKey;
  TeacherGroupListQuery? _inFlightQuery;
  Timer? _searchDebounce;
  int _operationGeneration = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherGroupListState build() {
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
    final sessionKey = TeacherSessionSnapshot.fromSession(
      session,
      surface,
    ).eligibleKey;
    if (sessionKey == null) {
      _clearActiveSession();

      return const TeacherGroupListState.initial();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _searchDebounce?.cancel();
    _invalidateOperations();
    _activeSessionKey = sessionKey;
    const query = TeacherGroupListQuery.initial();
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey)) {
        _startLogicalLoad(
          query,
          searchDraft: '',
          presentation: _LoadPresentation.initial,
        );
      }
    });

    return const TeacherGroupListState.loading(query: query, searchDraft: '');
  }

  void updateSearchDraft(String value) {
    final isValid = TeacherGroupListQuery.isSearchInputValid(value);
    _searchDebounce?.cancel();
    state = state.withSearchDraft(
      value,
      errorText: isValid ? null : 'Search must be 254 characters or fewer.',
    );
    if (!isValid) {
      return;
    }

    _searchDebounce = Timer(
      TeacherGroupListQuery.searchDebounceDuration,
      commitSearchNow,
    );
  }

  void commitSearchNow() {
    _searchDebounce?.cancel();
    final query = _queryWithCommittedDraft();
    if (query != null) {
      _commitQuery(query);
    }
  }

  void previousPage() {
    final pending = _queryWithCommittedDraft();
    if (pending == null) {
      return;
    }
    if (pending != state.query) {
      _commitQuery(pending);
      return;
    }
    if (!state.canGoPrevious) {
      return;
    }

    _commitQuery(state.query.withPage(state.query.page - 1));
  }

  void nextPage() {
    final pending = _queryWithCommittedDraft();
    if (pending == null) {
      return;
    }
    if (pending != state.query) {
      _commitQuery(pending);
      return;
    }
    if (!state.canGoNext) {
      return;
    }

    _commitQuery(state.query.withPage(state.query.page + 1));
  }

  void returnToFirstPage() {
    final pending = _queryWithCommittedDraft();
    if (pending == null) {
      return;
    }
    if (pending != state.query) {
      _commitQuery(pending);
      return;
    }
    if (state.query.page != TeacherGroupListQuery.initialPage) {
      _commitQuery(state.query.withPage(TeacherGroupListQuery.initialPage));
    }
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    final query = state.query.withSearch(null);
    state = state.withSearchDraft('');
    _commitQuery(query, searchDraft: '');
  }

  void refresh() {
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

  void refreshAfterSelectedGroupRevoked() {
    refresh();
  }

  void retry() {
    if (state.status != TeacherGroupListStatus.error ||
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

  TeacherGroupListQuery? _queryWithCommittedDraft() {
    _searchDebounce?.cancel();
    if (!_hasValidSearchDraft()) {
      return null;
    }
    final normalized = TeacherGroupListQuery.normalizeSearch(state.searchDraft);

    return normalized == state.query.search
        ? state.query
        : state.query.withSearch(normalized);
  }

  bool _hasValidSearchDraft() {
    if (TeacherGroupListQuery.isSearchInputValid(state.searchDraft)) {
      return true;
    }

    state = state.withSearchDraft(
      state.searchDraft,
      errorText: 'Search must be 254 characters or fewer.',
    );

    return false;
  }

  void _commitQuery(TeacherGroupListQuery query, {String? searchDraft}) {
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
      presentation: _LoadPresentation.query,
    );
  }

  void _startLogicalLoad(
    TeacherGroupListQuery query, {
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
      _LoadPresentation.initial => TeacherGroupListState.loading(
        query: query,
        searchDraft: searchDraft,
      ),
      _LoadPresentation.query => TeacherGroupListState.queryLoading(
        query: query,
        searchDraft: searchDraft,
      ),
      _LoadPresentation.refresh => TeacherGroupListState.refreshing(
        query: query,
        searchDraft: searchDraft,
        result: state.result!,
      ),
      _LoadPresentation.retry => state.retrying(),
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
    TeacherGroupListQuery query, {
    required TeacherSessionKey sessionKey,
    required int generation,
    required bool correctionUsed,
  }) async {
    try {
      final result = await ref
          .read(teacherGroupListRepositoryProvider)
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
        state = TeacherGroupListState.queryLoading(
          query: correctedQuery,
          searchDraft: state.searchDraft,
        );
        _restoreCurrentSearchError();
        await _load(
          correctedQuery,
          sessionKey: sessionKey,
          generation: generation,
          correctionUsed: true,
        );
        return;
      }

      state = TeacherGroupListState.fromResult(
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

      state = TeacherGroupListState.error(
        query: query,
        searchDraft: state.searchDraft,
        failure: exception.failure,
        searchErrorText: _currentSearchError,
      );
    } catch (_) {
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }

      state = TeacherGroupListState.error(
        query: query,
        searchDraft: state.searchDraft,
        failure: ApiFailure.local(
          kind: ApiFailureKind.unknown,
          message: 'Unexpected Teacher Group list failure.',
        ),
        searchErrorText: _currentSearchError,
      );
    } finally {
      if (generation == _operationGeneration && _inFlightQuery == query) {
        _inFlightQuery = null;
      }
    }
  }

  int? _correctionTarget(
    TeacherGroupListQuery query,
    TeacherGroupListPage result, {
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
    TeacherSessionKey sessionKey,
    TeacherGroupListQuery query,
  ) {
    return !_isDisposed &&
        generation == _operationGeneration &&
        _inFlightQuery == query &&
        state.query == query &&
        _matchesSession(sessionKey);
  }

  bool _matchesSession(TeacherSessionKey key) {
    return !_isDisposed &&
        _activeSessionKey == key &&
        TeacherSessionSnapshot.fromSession(
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
    state = const TeacherGroupListState.initial();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }

    return true;
  }

  String? get _currentSearchError =>
      TeacherGroupListQuery.isSearchInputValid(state.searchDraft)
      ? null
      : 'Search must be 254 characters or fewer.';

  void _restoreCurrentSearchError() {
    state = state.withSearchDraft(
      state.searchDraft,
      errorText: _currentSearchError,
    );
  }

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

enum _LoadPresentation { initial, query, refresh, retry }
