import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_blitz_repository_impl.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_list.dart';
import '../domain/teacher_blitz_list_query.dart';
import '../domain/teacher_topic.dart';
import 'teacher_blitz_list_state.dart';
import 'teacher_session_key.dart';

final teacherBlitzListControllerProvider = NotifierProvider.autoDispose
    .family<TeacherBlitzListController, TeacherBlitzListState, String>(
      TeacherBlitzListController.new,
    );

class TeacherBlitzListController extends Notifier<TeacherBlitzListState> {
  TeacherBlitzListController(this.topicId);

  final String topicId;
  TeacherSessionKey? _activeSessionKey;
  TeacherBlitzListQuery? _inFlightQuery;
  int _generation = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherBlitzListState build() {
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
      return const TeacherBlitzListState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = sessionKey;
    const query = TeacherBlitzListQuery.initial();
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey)) {
        _startLoad(query, retainResult: false);
      }
    });

    return const TeacherBlitzListState(status: TeacherBlitzListStatus.loading);
  }

  void setStatus(TeacherBlitzStatus? status) {
    if (status == state.query.status) {
      return;
    }
    _startLoad(state.query.withStatus(status), retainResult: false);
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
    if (_activeSessionKey == null) {
      return;
    }
    _startLoad(state.query, retainResult: state.result != null);
  }

  void retry() {
    if (state.status != TeacherBlitzListStatus.error ||
        _activeSessionKey == null) {
      return;
    }
    _startLoad(state.query, retainResult: state.result != null);
  }

  void _startLoad(TeacherBlitzListQuery query, {required bool retainResult}) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        !_matchesSession(sessionKey) ||
        (_inFlightQuery == query && state.isRequestInFlight)) {
      return;
    }

    final retainedResult = retainResult ? state.result : null;
    final generation = ++_generation;
    _inFlightQuery = query;
    state = TeacherBlitzListState(
      status: retainedResult == null
          ? TeacherBlitzListStatus.loading
          : TeacherBlitzListStatus.refreshing,
      query: query,
      result: retainedResult,
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
    TeacherBlitzListQuery query, {
    required TeacherSessionKey sessionKey,
    required int generation,
    required TeacherBlitzList? retainedResult,
  }) async {
    try {
      final result = await ref
          .read(teacherBlitzRepositoryProvider)
          .fetchBlitzList(topicId, query);
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }
      state = TeacherBlitzListState(
        status: TeacherBlitzListStatus.data,
        query: query,
        result: result,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      state = TeacherBlitzListState(
        status: TeacherBlitzListStatus.error,
        query: query,
        result: retainedResult,
        failure: exception.failure,
        isStale: retainedResult != null,
      );
    } catch (_) {
      if (_canPublish(generation, sessionKey, query)) {
        state = TeacherBlitzListState(
          status: TeacherBlitzListStatus.error,
          query: query,
          result: retainedResult,
          failure: ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Teacher Blitz list failure.',
          ),
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
    TeacherBlitzListQuery query,
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
    state = const TeacherBlitzListState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }

    return true;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _inFlightQuery = null;
    _generation += 1;
  }
}
