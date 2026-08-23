import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_topic_list_repository_impl.dart';
import '../domain/teacher_group.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_list.dart';
import '../domain/teacher_topic_list_query.dart';
import 'teacher_group_list_controller.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_list_state.dart';

final teacherTopicListControllerProvider =
    NotifierProvider.autoDispose<
      TeacherTopicListController,
      TeacherTopicListState
    >(TeacherTopicListController.new);

const teacherSelectedGroupUnavailableNotice =
    'The selected group is no longer available. Showing topics you can currently access.';

class TeacherTopicListController extends Notifier<TeacherTopicListState> {
  TeacherSessionKey? _activeSessionKey;
  TeacherTopicListQuery? _inFlightQuery;
  Timer? _searchDebounce;
  int _operationGeneration = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherTopicListState build() {
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

      return const TeacherTopicListState.initial();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _searchDebounce?.cancel();
    _invalidateOperations();
    _activeSessionKey = sessionKey;
    const query = TeacherTopicListQuery.initial();
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey)) {
        _startLogicalLoad(
          query,
          searchDraft: '',
          selectedGroup: null,
          presentation: _LoadPresentation.initial,
        );
      }
    });

    return const TeacherTopicListState.loading(
      query: query,
      searchDraft: '',
      selectedGroup: null,
    );
  }

  void updateSearchDraft(String value) {
    final isValid = TeacherTopicListQuery.isSearchInputValid(value);
    _searchDebounce?.cancel();
    state = state.withSearchDraft(
      value,
      errorText: isValid ? null : 'Search must be 254 characters or fewer.',
    );
    if (!isValid) {
      return;
    }

    _searchDebounce = Timer(
      TeacherTopicListQuery.searchDebounceDuration,
      commitSearchNow,
    );
  }

  void commitSearchNow() {
    _searchDebounce?.cancel();
    final query = _queryWithCommittedDraft();
    if (query != null) {
      _commitQuery(query, selectedGroup: state.selectedGroup);
    }
  }

  void setStatus(TeacherTopicStatus? status) {
    final base = _queryWithCommittedDraft();
    if (base == null) {
      return;
    }

    _commitQuery(base.withStatus(status), selectedGroup: state.selectedGroup);
  }

  void selectGroup(TeacherGroupSummary group) {
    final base = _queryWithCommittedDraft();
    if (base == null) {
      return;
    }

    _commitQuery(base.withGroupId(group.id), selectedGroup: group);
  }

  void clearGroupFilter() {
    final base = _queryWithCommittedDraft();
    if (base == null) {
      return;
    }

    _commitQuery(base.withGroupId(null), selectedGroup: null);
  }

  void previousPage() {
    final pending = _queryWithCommittedDraft();
    if (pending == null) {
      return;
    }
    if (pending != state.query) {
      _commitQuery(pending, selectedGroup: state.selectedGroup);
      return;
    }
    if (!state.canGoPrevious) {
      return;
    }

    _commitQuery(
      state.query.withPage(state.query.page - 1),
      selectedGroup: state.selectedGroup,
    );
  }

  void nextPage() {
    final pending = _queryWithCommittedDraft();
    if (pending == null) {
      return;
    }
    if (pending != state.query) {
      _commitQuery(pending, selectedGroup: state.selectedGroup);
      return;
    }
    if (!state.canGoNext) {
      return;
    }

    _commitQuery(
      state.query.withPage(state.query.page + 1),
      selectedGroup: state.selectedGroup,
    );
  }

  void returnToFirstPage() {
    final pending = _queryWithCommittedDraft();
    if (pending == null) {
      return;
    }
    if (pending != state.query) {
      _commitQuery(pending, selectedGroup: state.selectedGroup);
      return;
    }
    if (state.query.page != TeacherTopicListQuery.initialPage) {
      _commitQuery(
        state.query.withPage(TeacherTopicListQuery.initialPage),
        selectedGroup: state.selectedGroup,
      );
    }
  }

  void clearFilters() {
    _searchDebounce?.cancel();
    const query = TeacherTopicListQuery.initial();
    state = state.withSearchDraft('');
    _commitQuery(query, searchDraft: '', selectedGroup: null);
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
      selectedGroup: state.selectedGroup,
      presentation: presentation,
    );
  }

  void retry() {
    if (state.status != TeacherTopicListStatus.error ||
        state.isRetryInFlight ||
        _inFlightQuery != null) {
      return;
    }

    _searchDebounce?.cancel();
    _startLogicalLoad(
      state.query,
      searchDraft: state.searchDraft,
      selectedGroup: state.selectedGroup,
      presentation: _LoadPresentation.retry,
    );
  }

  void consumeNotice() {
    state = state.withoutNotice();
  }

  TeacherTopicListQuery? _queryWithCommittedDraft() {
    _searchDebounce?.cancel();
    if (!_hasValidSearchDraft()) {
      return null;
    }
    final normalized = TeacherTopicListQuery.normalizeSearch(state.searchDraft);

    return normalized == state.query.search
        ? state.query
        : state.query.withSearch(normalized);
  }

  bool _hasValidSearchDraft() {
    if (TeacherTopicListQuery.isSearchInputValid(state.searchDraft)) {
      return true;
    }

    state = state.withSearchDraft(
      state.searchDraft,
      errorText: 'Search must be 254 characters or fewer.',
    );

    return false;
  }

  void _commitQuery(
    TeacherTopicListQuery query, {
    required TeacherGroupSummary? selectedGroup,
    String? searchDraft,
  }) {
    final nextDraft = searchDraft ?? state.searchDraft;
    final selectionUnchanged = selectedGroup?.id == state.selectedGroup?.id;
    if (query == state.query && selectionUnchanged) {
      if (nextDraft != state.searchDraft || state.searchErrorText != null) {
        state = state.withSearchDraft(nextDraft);
      }
      return;
    }

    _startLogicalLoad(
      query,
      searchDraft: nextDraft,
      selectedGroup: selectedGroup,
      presentation: _LoadPresentation.query,
    );
  }

  void _startLogicalLoad(
    TeacherTopicListQuery query, {
    required String searchDraft,
    required TeacherGroupSummary? selectedGroup,
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
      _LoadPresentation.initial => TeacherTopicListState.loading(
        query: query,
        searchDraft: searchDraft,
        selectedGroup: selectedGroup,
      ),
      _LoadPresentation.query => TeacherTopicListState.queryLoading(
        query: query,
        searchDraft: searchDraft,
        selectedGroup: selectedGroup,
      ),
      _LoadPresentation.refresh => TeacherTopicListState.refreshing(
        query: query,
        searchDraft: searchDraft,
        selectedGroup: selectedGroup,
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
        reconciliationUsed: false,
        notice: null,
      ),
    );
  }

  Future<void> _load(
    TeacherTopicListQuery query, {
    required TeacherSessionKey sessionKey,
    required int generation,
    required bool correctionUsed,
    required bool reconciliationUsed,
    required String? notice,
  }) async {
    try {
      final result = await ref
          .read(teacherTopicListRepositoryProvider)
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
        final correctedQuery = query.withPage(correctionTarget);
        _inFlightQuery = correctedQuery;
        state = TeacherTopicListState.queryLoading(
          query: correctedQuery,
          searchDraft: state.searchDraft,
          selectedGroup: state.selectedGroup,
          notice: notice,
        );
        _restoreCurrentSearchError();
        await _load(
          correctedQuery,
          sessionKey: sessionKey,
          generation: generation,
          correctionUsed: true,
          reconciliationUsed: reconciliationUsed,
          notice: notice,
        );
        return;
      }

      state = TeacherTopicListState.fromResult(
        query: query,
        searchDraft: state.searchDraft,
        selectedGroup: state.selectedGroup,
        result: result,
        notice: notice,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      if (!reconciliationUsed &&
          query.groupId != null &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        final reconciledQuery = query.withGroupId(null);
        _inFlightQuery = reconciledQuery;
        state = TeacherTopicListState.queryLoading(
          query: reconciledQuery,
          searchDraft: state.searchDraft,
          selectedGroup: null,
          notice: teacherSelectedGroupUnavailableNotice,
        );
        _restoreCurrentSearchError();
        ref
            .read(teacherGroupListControllerProvider.notifier)
            .refreshAfterSelectedGroupRevoked();
        await _load(
          reconciledQuery,
          sessionKey: sessionKey,
          generation: generation,
          correctionUsed: false,
          reconciliationUsed: true,
          notice: teacherSelectedGroupUnavailableNotice,
        );
        return;
      }

      state = TeacherTopicListState.error(
        query: query,
        searchDraft: state.searchDraft,
        selectedGroup: state.selectedGroup,
        failure: exception.failure,
        notice: notice,
        searchErrorText: _currentSearchError,
      );
    } catch (_) {
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }

      state = TeacherTopicListState.error(
        query: query,
        searchDraft: state.searchDraft,
        selectedGroup: state.selectedGroup,
        failure: ApiFailure.local(
          kind: ApiFailureKind.unknown,
          message: 'Unexpected Teacher Topic list failure.',
        ),
        notice: notice,
        searchErrorText: _currentSearchError,
      );
    } finally {
      if (generation == _operationGeneration && _inFlightQuery == query) {
        _inFlightQuery = null;
      }
    }
  }

  int? _correctionTarget(
    TeacherTopicListQuery query,
    TeacherTopicListPage result, {
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
    TeacherSessionKey sessionKey,
    TeacherTopicListQuery query,
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
    state = const TeacherTopicListState.initial();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }

    return true;
  }

  String? get _currentSearchError =>
      TeacherTopicListQuery.isSearchInputValid(state.searchDraft)
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
