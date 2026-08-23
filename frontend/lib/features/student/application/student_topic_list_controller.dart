import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_topic_repository_impl.dart';
import '../domain/student_topic.dart';
import '../domain/student_topic_list.dart';
import '../domain/student_topic_list_query.dart';
import 'student_session_key.dart';
import 'student_topic_list_state.dart';

final studentTopicListControllerProvider =
    NotifierProvider.autoDispose<
      StudentTopicListController,
      StudentTopicListState
    >(StudentTopicListController.new);

final studentTopicListRetainedQueryProvider =
    Provider<StudentTopicListRetainedQueryStore>((ref) {
      final store = StudentTopicListRetainedQueryStore();
      ref.listen(authSessionControllerProvider, (_, next) {
        store.clearUnlessMatches(
          StudentSessionSnapshot.fromSession(
            next,
            ref.read(appDeviceSurfaceProvider),
          ).eligibleKey,
        );
      });
      ref.listen(appDeviceSurfaceProvider, (_, next) {
        store.clearUnlessMatches(
          StudentSessionSnapshot.fromSession(
            ref.read(authSessionControllerProvider),
            next,
          ).eligibleKey,
        );
      });

      return store;
    });

class StudentTopicListController extends Notifier<StudentTopicListState> {
  StudentSessionKey? _activeSessionKey;
  StudentTopicListQuery? _inFlightQuery;
  Timer? _searchDebounce;
  int _operationGeneration = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  StudentTopicListState build() {
    _isDisposed = false;
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() {
        _isDisposed = true;
        _searchDebounce?.cancel();
        _invalidateOperations();
      });
    }
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (key == null) {
      _clearActiveSession();
      return const StudentTopicListState.initial();
    }
    if (_activeSessionKey == key) {
      return state;
    }

    _searchDebounce?.cancel();
    _invalidateOperations();
    _activeSessionKey = key;
    final retainedStore = ref.read(studentTopicListRetainedQueryProvider);
    retainedStore.clearUnlessMatches(key);
    final retained = retainedStore.value;
    final query = retained?.matches(key) == true
        ? retained!.query
        : const StudentTopicListQuery.initial();
    final searchDraft = retained?.matches(key) == true
        ? retained!.searchDraft
        : query.search ?? '';
    scheduleMicrotask(() {
      if (_matchesSession(key)) {
        _startLogicalLoad(
          query,
          searchDraft: searchDraft,
          presentation: _LoadPresentation.initial,
        );
      }
    });

    return StudentTopicListState.loading(
      query: query,
      searchDraft: searchDraft,
    );
  }

  void updateSearchDraft(String value) {
    final valid = StudentTopicListQuery.isSearchInputValid(value);
    _searchDebounce?.cancel();
    state = state.withSearchDraft(
      value,
      errorText: valid ? null : 'Search must be 254 characters or fewer.',
    );
    _rememberQuery();
    if (!valid) {
      return;
    }
    _searchDebounce = Timer(
      StudentTopicListQuery.searchDebounceDuration,
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

  void setStatus(StudentTopicStatus? status) {
    final query = _queryWithCommittedDraft();
    if (query != null) {
      _commitQuery(query.withStatus(status));
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
    if (state.canGoPrevious) {
      _commitQuery(state.query.withPage(state.query.page - 1));
    }
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
    if (state.canGoNext) {
      _commitQuery(state.query.withPage(state.query.page + 1));
    }
  }

  void returnToFirstPage() {
    final pending = _queryWithCommittedDraft();
    if (pending == null) {
      return;
    }
    if (pending != state.query) {
      _commitQuery(pending);
    } else if (state.query.page != StudentTopicListQuery.initialPage) {
      _commitQuery(state.query.withPage(StudentTopicListQuery.initialPage));
    }
  }

  void clearFilters() {
    _searchDebounce?.cancel();
    state = state.withSearchDraft('');
    _commitQuery(const StudentTopicListQuery.initial(), searchDraft: '');
  }

  void refresh() {
    final query = _queryWithCommittedDraft();
    if (query == null) {
      return;
    }
    _startLogicalLoad(
      query,
      searchDraft: state.searchDraft,
      presentation: query == state.query && state.result != null
          ? _LoadPresentation.refresh
          : _LoadPresentation.query,
    );
  }

  void retry() {
    if (state.status != StudentTopicListStatus.error ||
        state.isRetryInFlight ||
        _inFlightQuery != null) {
      return;
    }
    final query = _queryWithCommittedDraft();
    if (query == null) {
      return;
    }
    if (query != state.query) {
      _commitQuery(query);
      return;
    }
    _startLogicalLoad(
      query,
      searchDraft: state.searchDraft,
      presentation: _LoadPresentation.retry,
    );
  }

  StudentTopicListQuery? _queryWithCommittedDraft() {
    _searchDebounce?.cancel();
    if (!StudentTopicListQuery.isSearchInputValid(state.searchDraft)) {
      state = state.withSearchDraft(
        state.searchDraft,
        errorText: 'Search must be 254 characters or fewer.',
      );
      return null;
    }
    final normalized = StudentTopicListQuery.normalizeSearch(state.searchDraft);
    return normalized == state.query.search
        ? state.query
        : state.query.withSearch(normalized);
  }

  void _commitQuery(StudentTopicListQuery query, {String? searchDraft}) {
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
    StudentTopicListQuery query, {
    required String searchDraft,
    required _LoadPresentation presentation,
  }) {
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        (_inFlightQuery == query && state.isRequestInFlight)) {
      return;
    }
    final generation = ++_operationGeneration;
    _inFlightQuery = query;
    state = switch (presentation) {
      _LoadPresentation.initial => StudentTopicListState.loading(
        query: query,
        searchDraft: searchDraft,
      ),
      _LoadPresentation.query => StudentTopicListState.queryLoading(
        query: query,
        searchDraft: searchDraft,
      ),
      _LoadPresentation.refresh => StudentTopicListState.refreshing(
        query: query,
        searchDraft: searchDraft,
        result: state.result!,
      ),
      _LoadPresentation.retry => state.retrying(),
    };
    _rememberQuery();
    unawaited(
      _load(
        query,
        sessionKey: key,
        generation: generation,
        correctionUsed: false,
      ),
    );
  }

  Future<void> _load(
    StudentTopicListQuery query, {
    required StudentSessionKey sessionKey,
    required int generation,
    required bool correctionUsed,
  }) async {
    try {
      final result = await ref
          .read(studentTopicRepositoryProvider)
          .fetchTopics(query);
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }
      final correctionTarget = _correctionTarget(
        query,
        result,
        correctionUsed: correctionUsed,
      );
      if (correctionTarget != null) {
        final corrected = query.withPage(correctionTarget);
        _inFlightQuery = corrected;
        state = StudentTopicListState.queryLoading(
          query: corrected,
          searchDraft: state.searchDraft,
        );
        _restoreSearchError();
        await _load(
          corrected,
          sessionKey: sessionKey,
          generation: generation,
          correctionUsed: true,
        );
        return;
      }
      state = StudentTopicListState.fromResult(
        query: query,
        searchDraft: state.searchDraft,
        result: result,
      );
      _rememberQuery();
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      state = StudentTopicListState.error(
        query: query,
        searchDraft: state.searchDraft,
        failure: exception.failure,
        searchErrorText: _currentSearchError,
      );
    } catch (_) {
      if (_canPublish(generation, sessionKey, query)) {
        state = StudentTopicListState.error(
          query: query,
          searchDraft: state.searchDraft,
          failure: ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Student Topic list failure.',
          ),
          searchErrorText: _currentSearchError,
        );
      }
    } finally {
      if (generation == _operationGeneration && _inFlightQuery == query) {
        _inFlightQuery = null;
      }
    }
  }

  int? _correctionTarget(
    StudentTopicListQuery query,
    StudentTopicListPage result, {
    required bool correctionUsed,
  }) {
    if (correctionUsed || result.topics.isNotEmpty || query.page <= 1) {
      return null;
    }
    final target = result.pagination.total == 0
        ? 1
        : math.max(1, math.min(result.pagination.lastPage, query.page - 1));
    return target == query.page ? null : target;
  }

  bool _canPublish(
    int generation,
    StudentSessionKey key,
    StudentTopicListQuery query,
  ) {
    return !_isDisposed &&
        generation == _operationGeneration &&
        _inFlightQuery == query &&
        state.query == query &&
        _matchesSession(key);
  }

  bool _matchesSession(StudentSessionKey key) {
    return !_isDisposed &&
        _activeSessionKey == key &&
        StudentSessionSnapshot.fromSession(
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
    state = const StudentTopicListState.initial();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  String? get _currentSearchError =>
      StudentTopicListQuery.isSearchInputValid(state.searchDraft)
      ? null
      : 'Search must be 254 characters or fewer.';

  void _restoreSearchError() {
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

  void _rememberQuery() {
    final key = _activeSessionKey;
    if (key == null) {
      return;
    }
    ref
        .read(studentTopicListRetainedQueryProvider)
        .value = StudentTopicListRetainedQuery(
      sessionKey: key,
      query: state.query,
      searchDraft: state.searchDraft,
    );
  }
}

class StudentTopicListRetainedQueryStore {
  StudentTopicListRetainedQuery? value;

  void clearUnlessMatches(StudentSessionKey? key) {
    if (key == null || value?.matches(key) != true) {
      value = null;
    }
  }

  void markAuthoritativeRowsStale(StudentSessionKey key) {
    final retained = value;
    if (retained?.matches(key) != true) {
      value = StudentTopicListRetainedQuery(
        sessionKey: key,
        query: const StudentTopicListQuery.initial(),
        searchDraft: '',
      );
    }
  }
}

class StudentTopicListRetainedQuery {
  const StudentTopicListRetainedQuery({
    required this.sessionKey,
    required this.query,
    required this.searchDraft,
  });

  final StudentSessionKey sessionKey;
  final StudentTopicListQuery query;
  final String searchDraft;

  bool matches(StudentSessionKey key) => sessionKey == key;
}

enum _LoadPresentation { initial, query, refresh, retry }
