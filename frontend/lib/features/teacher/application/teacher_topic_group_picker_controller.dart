import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_group_list_repository_impl.dart';
import '../domain/teacher_group.dart';
import '../domain/teacher_group_list_query.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_group_picker_state.dart';

final teacherTopicGroupPickerControllerProvider =
    NotifierProvider.autoDispose<
      TeacherTopicGroupPickerController,
      TeacherTopicGroupPickerState
    >(TeacherTopicGroupPickerController.new);

class TeacherTopicGroupPickerController
    extends Notifier<TeacherTopicGroupPickerState> {
  TeacherSessionKey? _activeSessionKey;
  TeacherGroupListQuery? _inFlightQuery;
  Timer? _searchDebounce;
  int _generation = 0;
  var _disposeRegistered = false;

  @override
  TeacherTopicGroupPickerState build() {
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() {
        _searchDebounce?.cancel();
        _generation += 1;
        _inFlightQuery = null;
      });
    }
    final key = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (key == null || key.surface != AppDeviceSurface.desktop) {
      _clearOwnership();
      return const TeacherTopicGroupPickerState();
    }
    if (_activeSessionKey == key) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = key;
    const query = TeacherGroupListQuery.initial();
    scheduleMicrotask(() => _load(query, key));

    return const TeacherTopicGroupPickerState(
      status: TeacherTopicGroupPickerStatus.loading,
    );
  }

  void updateSearchDraft(String value) {
    _searchDebounce?.cancel();
    final valid = TeacherGroupListQuery.isSearchInputValid(value);
    state = state.copyWith(
      searchDraft: value,
      searchErrorText: valid ? null : 'Search must be 254 characters or fewer.',
    );
    if (valid) {
      _searchDebounce = Timer(
        TeacherGroupListQuery.searchDebounceDuration,
        commitSearchNow,
      );
    }
  }

  void commitSearchNow() {
    _searchDebounce?.cancel();
    if (!TeacherGroupListQuery.isSearchInputValid(state.searchDraft)) {
      return;
    }
    final query = state.query.withSearch(state.searchDraft);
    if (query != state.query) {
      _startLoad(query);
    }
  }

  void previousPage() {
    if (state.canPrevious) {
      _startLoad(state.query.withPage(state.query.page - 1));
    }
  }

  void nextPage() {
    if (state.canNext) {
      _startLoad(state.query.withPage(state.query.page + 1));
    }
  }

  void refresh() {
    if (!state.isLoading && state.searchErrorText == null) {
      _startLoad(state.query);
    }
  }

  void selectGroup(TeacherGroupSummary group) {
    if (group.status != TeacherGroupStatus.active || state.isLoading) {
      return;
    }
    state = state.copyWith(selectedGroup: group);
  }

  void clearSelection({bool refresh = false}) {
    state = state.copyWith(selectedGroup: null);
    if (refresh) {
      _startLoad(state.query);
    }
  }

  void _startLoad(TeacherGroupListQuery query) {
    final key = _activeSessionKey;
    if (key == null || !_matchesSession(key)) {
      return;
    }
    _load(query, key);
  }

  Future<void> _load(TeacherGroupListQuery query, TeacherSessionKey key) async {
    if (_inFlightQuery == query && state.isLoading) {
      return;
    }
    final generation = ++_generation;
    _inFlightQuery = query;
    state = state.copyWith(
      status: TeacherTopicGroupPickerStatus.loading,
      query: query,
      result: null,
      failure: null,
    );
    try {
      final result = await ref
          .read(teacherGroupListRepositoryProvider)
          .fetchGroups(query);
      if (!_canPublish(generation, key, query)) {
        return;
      }
      if (result.groups.any(
        (group) => group.status != TeacherGroupStatus.active,
      )) {
        throw const FormatException(
          'Topic Group picker received an inactive Group.',
        );
      }
      if (result.groups.isEmpty && query.page > 1) {
        final target = result.pagination.total == 0
            ? 1
            : math.max(1, math.min(result.pagination.lastPage, query.page - 1));
        if (target != query.page) {
          _inFlightQuery = null;
          await _load(query.withPage(target), key);
          return;
        }
      }
      state = state.copyWith(
        status: result.groups.isEmpty
            ? TeacherTopicGroupPickerStatus.empty
            : TeacherTopicGroupPickerStatus.data,
        result: result,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key, query)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      state = state.copyWith(
        status: TeacherTopicGroupPickerStatus.error,
        failure: exception.failure,
      );
    } catch (_) {
      if (!_canPublish(generation, key, query)) {
        return;
      }
      state = state.copyWith(
        status: TeacherTopicGroupPickerStatus.error,
        failure: ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Unexpected assigned Group picker response.',
        ),
      );
    } finally {
      if (generation == _generation) {
        _inFlightQuery = null;
      }
    }
  }

  bool _canPublish(
    int generation,
    TeacherSessionKey key,
    TeacherGroupListQuery query,
  ) {
    return ref.mounted &&
        generation == _generation &&
        _inFlightQuery == query &&
        state.query == query &&
        _matchesSession(key);
  }

  bool _matchesSession(TeacherSessionKey key) {
    return ref.mounted &&
        _activeSessionKey == key &&
        TeacherSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            key &&
        key.surface == AppDeviceSurface.desktop;
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
    state = const TeacherTopicGroupPickerState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }

    return true;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _searchDebounce?.cancel();
    _generation += 1;
    _inFlightQuery = null;
  }
}
