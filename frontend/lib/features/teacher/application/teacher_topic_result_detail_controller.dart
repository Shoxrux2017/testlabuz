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
import 'teacher_session_key.dart';
import 'teacher_topic_result_detail_state.dart';
import 'teacher_topic_result_target.dart';

final teacherTopicResultDetailControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherTopicResultDetailController,
      TeacherTopicResultDetailState,
      TeacherTopicResultTarget
    >(TeacherTopicResultDetailController.new);

/// One cohort Student's Topic result
/// (`GET /teacher/topics/{topic}/results/{student}`).
class TeacherTopicResultDetailController
    extends Notifier<TeacherTopicResultDetailState> {
  TeacherTopicResultDetailController(this.target);

  final TeacherTopicResultTarget target;
  TeacherSessionKey? _activeSessionKey;
  var _requestActive = false;
  var _generation = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherTopicResultDetailState build() {
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
    if (!isCanonicalTeacherTopicId(target.topicId) ||
        !isCanonicalTeacherStudentId(target.studentId) ||
        sessionKey == null) {
      _clearOwnership();
      return const TeacherTopicResultDetailState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = sessionKey;
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey)) {
        unawaited(_startLoad(retainDetail: false));
      }
    });
    return const TeacherTopicResultDetailState(
      status: TeacherTopicResultDetailStatus.loading,
    );
  }

  Future<void> refresh() {
    if (_requestActive || _activeSessionKey == null) {
      return Future<void>.value();
    }
    return _startLoad(retainDetail: state.detail != null);
  }

  Future<void> _startLoad({required bool retainDetail}) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null || _requestActive || !_matchesSession(sessionKey)) {
      return Future<void>.value();
    }

    final retainedDetail = retainDetail ? state.detail : null;
    final generation = ++_generation;
    _requestActive = true;
    state = TeacherTopicResultDetailState(
      status: retainedDetail == null
          ? TeacherTopicResultDetailStatus.loading
          : TeacherTopicResultDetailStatus.refreshing,
      detail: retainedDetail,
    );
    return _load(
      sessionKey: sessionKey,
      generation: generation,
      retainedDetail: retainedDetail,
    );
  }

  Future<void> _load({
    required TeacherSessionKey sessionKey,
    required int generation,
    required TeacherTopicResultDetail? retainedDetail,
  }) async {
    try {
      final detail = await ref
          .read(teacherTopicResultRepositoryProvider)
          .fetchResult(target.topicId, target.studentId);
      if (!_canPublish(generation, sessionKey)) {
        return;
      }
      state = TeacherTopicResultDetailState(
        status: TeacherTopicResultDetailStatus.data,
        detail: detail,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      _publishFailure(retainedDetail, exception.failure);
    } catch (_) {
      if (_canPublish(generation, sessionKey)) {
        _publishFailure(
          retainedDetail,
          ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Teacher Topic result failure.',
          ),
        );
      }
    } finally {
      if (generation == _generation) {
        _requestActive = false;
      }
    }
  }

  void _publishFailure(
    TeacherTopicResultDetail? retainedDetail,
    ApiFailure failure,
  ) {
    state = TeacherTopicResultDetailState(
      status: TeacherTopicResultDetailStatus.error,
      detail: retainedDetail,
      failure: failure,
      isStale: retainedDetail != null,
    );
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
    state = const TeacherTopicResultDetailState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _requestActive = false;
    _generation += 1;
  }
}
