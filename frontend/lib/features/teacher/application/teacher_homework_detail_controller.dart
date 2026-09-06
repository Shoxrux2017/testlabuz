import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_homework_repository_impl.dart';
import '../domain/teacher_homework.dart';
import 'teacher_homework_detail_state.dart';
import 'teacher_homework_route_target.dart';
import 'teacher_session_key.dart';

final teacherHomeworkDetailControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherHomeworkDetailController,
      TeacherHomeworkDetailState,
      TeacherHomeworkRouteTarget
    >(TeacherHomeworkDetailController.new);

class TeacherHomeworkDetailController
    extends Notifier<TeacherHomeworkDetailState> {
  TeacherHomeworkDetailController(this.target);

  final TeacherHomeworkRouteTarget target;
  TeacherSessionKey? _activeSessionKey;
  var _requestActive = false;
  int _generation = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  TeacherHomeworkDetailState build() {
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
    if (sessionKey == null) {
      _clearOwnership();
      return const TeacherHomeworkDetailState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = sessionKey;
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey)) {
        _startLoad(retainHomework: false);
      }
    });

    return const TeacherHomeworkDetailState(
      status: TeacherHomeworkDetailStatus.loading,
    );
  }

  void refresh() {
    if (_requestActive || _activeSessionKey == null) {
      return;
    }
    _startLoad(retainHomework: state.homework != null);
  }

  void retry() {
    if (_requestActive ||
        _activeSessionKey == null ||
        state.status != TeacherHomeworkDetailStatus.error) {
      return;
    }
    _startLoad(retainHomework: state.homework != null);
  }

  void _startLoad({required bool retainHomework}) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null || _requestActive || !_matchesSession(sessionKey)) {
      return;
    }

    final retainedHomework = retainHomework ? state.homework : null;
    final generation = ++_generation;
    _requestActive = true;
    state = TeacherHomeworkDetailState(
      status: retainedHomework == null
          ? TeacherHomeworkDetailStatus.loading
          : TeacherHomeworkDetailStatus.refreshing,
      homework: retainedHomework,
    );
    unawaited(
      _load(
        sessionKey: sessionKey,
        generation: generation,
        retainedHomework: retainedHomework,
      ),
    );
  }

  Future<void> _load({
    required TeacherSessionKey sessionKey,
    required int generation,
    required TeacherHomework? retainedHomework,
  }) async {
    try {
      final homework = await ref
          .read(teacherHomeworkRepositoryProvider)
          .fetchHomework(target.homeworkId);
      if (!_canPublish(generation, sessionKey)) {
        return;
      }
      if (homework.topicId.toLowerCase() != target.topicId.toLowerCase()) {
        state = const TeacherHomeworkDetailState(
          status: TeacherHomeworkDetailStatus.notFound,
        );
        return;
      }
      state = TeacherHomeworkDetailState(
        status: TeacherHomeworkDetailStatus.data,
        homework: homework,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey)) {
        return;
      }
      if (_clearForSessionFailure(exception.failure)) {
        return;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        state = const TeacherHomeworkDetailState(
          status: TeacherHomeworkDetailStatus.notFound,
        );
        return;
      }
      state = TeacherHomeworkDetailState(
        status: TeacherHomeworkDetailStatus.error,
        homework: retainedHomework,
        failure: exception.failure,
        isStale: retainedHomework != null,
      );
    } catch (_) {
      if (_canPublish(generation, sessionKey)) {
        state = TeacherHomeworkDetailState(
          status: TeacherHomeworkDetailStatus.error,
          homework: retainedHomework,
          failure: ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Teacher Homework detail failure.',
          ),
          isStale: retainedHomework != null,
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
    state = const TeacherHomeworkDetailState();
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
