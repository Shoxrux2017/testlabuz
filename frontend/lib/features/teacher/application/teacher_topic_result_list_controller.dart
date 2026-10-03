import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_topic_result_repository_impl.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_result.dart';
import '../domain/teacher_topic_result_list.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_result_list_state.dart';

/// Keyed by the lowercase Topic id; the Topic detail entry card and the
/// results screen share one controller, so they show the same counts.
final teacherTopicResultListControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherTopicResultListController,
      TeacherTopicResultListState,
      String
    >(TeacherTopicResultListController.new);

/// The Topic results list (`GET /teacher/topics/{topic}/results`) with its
/// status and category filters and pages, on desktop and mobile
/// (`S10-FE-D1`).
class TeacherTopicResultListController
    extends Notifier<TeacherTopicResultListState> {
  TeacherTopicResultListController(this.topicId);

  final String topicId;
  TeacherSessionKey? _activeSessionKey;
  TeacherTopicResultListQuery? _inFlightQuery;
  int _generation = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherTopicResultListState build() {
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
      return const TeacherTopicResultListState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = sessionKey;
    const query = TeacherTopicResultListQuery();
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey)) {
        _startLoad(query, retainResult: false);
      }
    });

    return const TeacherTopicResultListState(
      status: TeacherTopicResultListStatus.loading,
    );
  }

  void setStatus(TeacherTopicResultStatus? value) {
    if (value != state.query.status) {
      _startLoad(state.query.withStatus(value), retainResult: false);
    }
  }

  void setCategory(TeacherTopicResultCategoryCode? value) {
    if (value != state.query.category) {
      _startLoad(state.query.withCategory(value), retainResult: false);
    }
  }

  void clearFilters() {
    const query = TeacherTopicResultListQuery();
    if (query != state.query) {
      _startLoad(query, retainResult: false);
    }
  }

  void previousPage() {
    if (state.canGoPrevious) {
      _startLoad(
        state.query.withPage(state.query.page - 1),
        retainResult: false,
      );
    }
  }

  void nextPage() {
    if (state.canGoNext) {
      _startLoad(
        state.query.withPage(state.query.page + 1),
        retainResult: false,
      );
    }
  }

  void refresh() {
    if (_activeSessionKey != null) {
      _startLoad(state.query, retainResult: state.result != null);
    }
  }

  void retry() {
    if (state.status == TeacherTopicResultListStatus.error &&
        _activeSessionKey != null) {
      _startLoad(state.query, retainResult: state.result != null);
    }
  }

  void _startLoad(
    TeacherTopicResultListQuery query, {
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
    state = TeacherTopicResultListState(
      status: retainedResult == null
          ? TeacherTopicResultListStatus.loading
          : TeacherTopicResultListStatus.refreshing,
      query: query,
      result: retainedResult,
      counts: state.counts,
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
    TeacherTopicResultListQuery query, {
    required TeacherSessionKey sessionKey,
    required int generation,
    required TeacherTopicResultList? retainedResult,
  }) async {
    try {
      final result = await ref
          .read(teacherTopicResultRepositoryProvider)
          .fetchResults(topicId, query);
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }
      state = TeacherTopicResultListState(
        status: TeacherTopicResultListStatus.data,
        query: query,
        result: result,
        counts: result.counts,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey, query)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      _publishFailure(query, retainedResult, exception.failure);
    } catch (_) {
      if (_canPublish(generation, sessionKey, query)) {
        _publishFailure(
          query,
          retainedResult,
          ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Teacher Topic result list failure.',
          ),
        );
      }
    } finally {
      if (generation == _generation && _inFlightQuery == query) {
        _inFlightQuery = null;
      }
    }
  }

  void _publishFailure(
    TeacherTopicResultListQuery query,
    TeacherTopicResultList? retainedResult,
    ApiFailure failure,
  ) {
    state = TeacherTopicResultListState(
      status: TeacherTopicResultListStatus.error,
      query: query,
      result: retainedResult,
      counts: state.counts,
      failure: failure,
      isStale: retainedResult != null,
    );
  }

  bool _canPublish(
    int generation,
    TeacherSessionKey sessionKey,
    TeacherTopicResultListQuery query,
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
    state = const TeacherTopicResultListState();
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
