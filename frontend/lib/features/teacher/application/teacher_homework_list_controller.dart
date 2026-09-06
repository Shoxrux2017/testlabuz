import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_homework_repository_impl.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_homework_list.dart';
import '../domain/teacher_homework_list_query.dart';
import '../domain/teacher_topic.dart';
import 'teacher_homework_list_state.dart';
import 'teacher_session_key.dart';

final teacherHomeworkListControllerProvider = NotifierProvider.autoDispose
    .family<TeacherHomeworkListController, TeacherHomeworkListState, String>(
      TeacherHomeworkListController.new,
    );

const teacherHomeworkSearchLengthError =
    'Search must be 160 characters or fewer.';

class TeacherHomeworkListController extends Notifier<TeacherHomeworkListState> {
  TeacherHomeworkListController(this.topicId);

  final String topicId;
  TeacherSessionKey? _activeSessionKey;
  TeacherHomeworkListQuery? _inFlightQuery;
  int _generation = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherHomeworkListState build() {
    _isDisposed = false;
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() {
        _isDisposed = true;
        _clearOwnership();
      });
    }

    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (!isCanonicalTeacherTopicId(topicId) || sessionKey == null) {
      _clearOwnership();
      return const TeacherHomeworkListState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = sessionKey;
    const query = TeacherHomeworkListQuery.initial();
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey)) {
        _startLoad(query, retainResult: false);
      }
    });

    return const TeacherHomeworkListState(
      status: TeacherHomeworkListStatus.loading,
    );
  }

  void updateSearchDraft(String value) {
    state = state.withSearchDraft(
      value,
      errorText: _isSearchDraftValid(value)
          ? null
          : teacherHomeworkSearchLengthError,
    );
  }

  void submitSearch() {
    if (!_validateSearchDraft()) {
      return;
    }
    final normalized = TeacherHomeworkListQuery.normalizeSearch(
      state.searchDraft,
    );
    if (normalized == state.query.search) {
      return;
    }
    final query = state.query.withSearch(normalized);

    _startLoad(query, retainResult: false);
  }

  void setStatus(TeacherHomeworkStatus? status) {
    if (status == state.query.status) {
      return;
    }
    final query = state.query.withStatus(status);
    _startLoad(query, retainResult: false);
  }

  void setAssignmentMode(TeacherHomeworkAssignmentMode? assignmentMode) {
    if (assignmentMode == state.query.assignmentMode) {
      return;
    }
    final query = state.query.withAssignmentMode(assignmentMode);
    _startLoad(query, retainResult: false);
  }

  void clearFilters() {
    const query = TeacherHomeworkListQuery.initial();
    final shouldLoad = query != state.query;
    state = state.withSearchDraft('');
    if (shouldLoad) {
      _startLoad(query, retainResult: false);
    }
  }

  void previousPage() {
    if (!state.canGoPrevious) {
      return;
    }
    _startLoad(state.query.withPage(state.query.page - 1), retainResult: false);
  }

  void nextPage() {
    if (!state.canGoNext) {
      return;
    }
    _startLoad(state.query.withPage(state.query.page + 1), retainResult: false);
  }

  void refresh() {
    if (_activeSessionKey == null || !_validateSearchDraft()) {
      return;
    }
    _startLoad(state.query, retainResult: state.result != null);
  }

  void retry() {
    if (state.status != TeacherHomeworkListStatus.error ||
        _activeSessionKey == null ||
        !_validateSearchDraft()) {
      return;
    }
    _startLoad(state.query, retainResult: state.result != null);
  }

  void _startLoad(
    TeacherHomeworkListQuery query, {
    required bool retainResult,
  }) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        !_matchesSession(sessionKey) ||
        (_inFlightQuery == query && state.isRequestInFlight)) {
      return;
    }

    final retainedResult = retainResult ? state.result : null;
    final generation = ++_generation;
    _inFlightQuery = query;
    state = TeacherHomeworkListState(
      status: retainedResult == null
          ? TeacherHomeworkListStatus.loading
          : TeacherHomeworkListStatus.refreshing,
      query: query,
      searchDraft: state.searchDraft,
      result: retainedResult,
      searchErrorText: _searchErrorText,
    );
    unawaited(
      _load(
        query,
        sessionKey: sessionKey,
        generation: generation,
        retainedResult: retainedResult,
      ),
    );
  }

  Future<void> _load(
    TeacherHomeworkListQuery query, {
    required TeacherSessionKey sessionKey,
    required int generation,
    required TeacherHomeworkList? retainedResult,
  }) async {
    try {
      final result = await ref
          .read(teacherHomeworkRepositoryProvider)
          .fetchHomeworkList(topicId, query);
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }
      state = TeacherHomeworkListState(
        status: TeacherHomeworkListStatus.data,
        query: query,
        searchDraft: state.searchDraft,
        result: result,
        searchErrorText: _searchErrorText,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      state = TeacherHomeworkListState(
        status: TeacherHomeworkListStatus.error,
        query: query,
        searchDraft: state.searchDraft,
        result: retainedResult,
        failure: exception.failure,
        searchErrorText: _searchErrorText,
        isStale: retainedResult != null,
      );
    } catch (_) {
      if (_canPublish(generation, sessionKey, query)) {
        state = TeacherHomeworkListState(
          status: TeacherHomeworkListStatus.error,
          query: query,
          searchDraft: state.searchDraft,
          result: retainedResult,
          failure: ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Teacher Homework list failure.',
          ),
          searchErrorText: _searchErrorText,
          isStale: retainedResult != null,
        );
      }
    } finally {
      if (generation == _generation && _inFlightQuery == query) {
        _inFlightQuery = null;
      }
    }
  }

  bool _canPublish(
    int generation,
    TeacherSessionKey sessionKey,
    TeacherHomeworkListQuery query,
  ) {
    return ref.mounted &&
        !_isDisposed &&
        generation == _generation &&
        _inFlightQuery == query &&
        state.query == query &&
        _matchesSession(sessionKey);
  }

  bool _matchesSession(TeacherSessionKey sessionKey) {
    return ref.mounted &&
        !_isDisposed &&
        _activeSessionKey == sessionKey &&
        TeacherSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            sessionKey;
  }

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }

    _clearOwnership();
    state = const TeacherHomeworkListState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }

    return true;
  }

  bool _validateSearchDraft() {
    final errorText = _searchErrorText;
    if (errorText == null) {
      if (state.searchErrorText != null) {
        state = state.withSearchDraft(state.searchDraft);
      }
      return true;
    }

    state = state.withSearchDraft(state.searchDraft, errorText: errorText);
    return false;
  }

  String? get _searchErrorText => _isSearchDraftValid(state.searchDraft)
      ? null
      : teacherHomeworkSearchLengthError;

  bool _isSearchDraftValid(String value) {
    return TeacherHomeworkListQuery.isSearchInputValid(value);
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _inFlightQuery = null;
    _generation += 1;
  }
}
