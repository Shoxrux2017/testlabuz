import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_topic_result_pair_repository_impl.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_result_pair.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_result_pair_state.dart';

final teacherTopicResultPairControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherTopicResultPairController,
      TeacherTopicResultPairState,
      String
    >(TeacherTopicResultPairController.new);

class TeacherTopicResultPairController
    extends Notifier<TeacherTopicResultPairState> {
  TeacherTopicResultPairController(this.topicId);

  final String topicId;
  TeacherSessionKey? _activeSessionKey;
  var _requestActive = false;
  var _generation = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherTopicResultPairState build() {
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
      return const TeacherTopicResultPairState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = sessionKey;
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey)) {
        unawaited(_startLoad(retainConfirmedValue: false));
      }
    });
    return const TeacherTopicResultPairState(
      status: TeacherTopicResultPairStatus.loading,
    );
  }

  Future<void> refresh() {
    if (_requestActive || _activeSessionKey == null) {
      return Future<void>.value();
    }
    return _startLoad(
      retainConfirmedValue:
          state.status == TeacherTopicResultPairStatus.data || state.isStale,
    );
  }

  Future<void> refreshAfterMutation(TeacherSessionKey originatingSessionKey) {
    if (!_matchesSession(originatingSessionKey)) {
      return Future<void>.value();
    }
    final retainConfirmedValue =
        state.status == TeacherTopicResultPairStatus.data ||
        state.status == TeacherTopicResultPairStatus.refreshing ||
        state.isStale;
    _cancelActiveRequest();
    return _startLoad(retainConfirmedValue: retainConfirmedValue);
  }

  Future<void> retry() {
    if (_requestActive ||
        _activeSessionKey == null ||
        state.status != TeacherTopicResultPairStatus.error) {
      return Future<void>.value();
    }
    return _startLoad(retainConfirmedValue: state.isStale);
  }

  void acceptAuthoritativePair(
    TeacherTopicResultPair pair,
    TeacherSessionKey originatingSessionKey,
  ) {
    if (!_matchesSession(originatingSessionKey) ||
        pair.topicId.toLowerCase() != topicId.toLowerCase()) {
      return;
    }
    _cancelActiveRequest();
    state = TeacherTopicResultPairState(
      status: TeacherTopicResultPairStatus.data,
      pair: pair,
    );
  }

  void acceptNoPair(TeacherSessionKey originatingSessionKey) {
    if (!_matchesSession(originatingSessionKey)) {
      return;
    }
    _cancelActiveRequest();
    state = const TeacherTopicResultPairState(
      status: TeacherTopicResultPairStatus.data,
    );
  }

  void acceptReadFailure(
    ApiFailure failure,
    TeacherSessionKey originatingSessionKey,
  ) {
    if (!_matchesSession(originatingSessionKey)) {
      return;
    }
    if (_clearForSessionFailure(failure)) {
      return;
    }
    final retainedConfirmedValue =
        state.status == TeacherTopicResultPairStatus.data || state.isStale;
    final retainedPair = retainedConfirmedValue ? state.pair : null;
    _cancelActiveRequest();
    state = TeacherTopicResultPairState(
      status: TeacherTopicResultPairStatus.error,
      pair: retainedPair,
      failure: failure,
      isStale: retainedConfirmedValue,
    );
  }

  Future<void> _startLoad({required bool retainConfirmedValue}) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null || _requestActive || !_matchesSession(sessionKey)) {
      return Future<void>.value();
    }

    final retainedPair = retainConfirmedValue ? state.pair : null;
    final generation = ++_generation;
    _requestActive = true;
    state = TeacherTopicResultPairState(
      status: retainConfirmedValue
          ? TeacherTopicResultPairStatus.refreshing
          : TeacherTopicResultPairStatus.loading,
      pair: retainedPair,
    );
    return _load(
      sessionKey: sessionKey,
      generation: generation,
      retainedPair: retainedPair,
      retainedConfirmedValue: retainConfirmedValue,
    );
  }

  Future<void> _load({
    required TeacherSessionKey sessionKey,
    required int generation,
    required TeacherTopicResultPair? retainedPair,
    required bool retainedConfirmedValue,
  }) async {
    try {
      final pair = await ref
          .read(teacherTopicResultPairRepositoryProvider)
          .fetchResultPair(topicId);
      if (!_canPublish(generation, sessionKey)) {
        return;
      }
      state = TeacherTopicResultPairState(
        status: TeacherTopicResultPairStatus.data,
        pair: pair,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      state = TeacherTopicResultPairState(
        status: TeacherTopicResultPairStatus.error,
        pair: retainedPair,
        failure: exception.failure,
        isStale: retainedConfirmedValue,
      );
    } catch (_) {
      if (_canPublish(generation, sessionKey)) {
        state = TeacherTopicResultPairState(
          status: TeacherTopicResultPairStatus.error,
          pair: retainedPair,
          failure: ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected official Homework status failure.',
          ),
          isStale: retainedConfirmedValue,
        );
      }
    } finally {
      if (generation == _generation) {
        _requestActive = false;
      }
    }
  }

  bool _canPublish(int generation, TeacherSessionKey sessionKey) {
    return ref.mounted &&
        !_isDisposed &&
        _requestActive &&
        generation == _generation &&
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
    state = const TeacherTopicResultPairState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _cancelActiveRequest();
  }

  void _cancelActiveRequest() {
    _requestActive = false;
    _generation += 1;
  }
}
