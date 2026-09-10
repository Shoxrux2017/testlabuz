import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_homework_repository_impl.dart';
import '../domain/student_homework_route_target.dart';
import 'student_homework_detail_state.dart';
import 'student_homework_list_controller.dart';
import 'student_session_key.dart';

final studentHomeworkDetailControllerProvider = NotifierProvider.autoDispose
    .family<
      StudentHomeworkDetailController,
      StudentHomeworkDetailState,
      StudentHomeworkRouteTarget
    >(StudentHomeworkDetailController.new);

class StudentHomeworkDetailController
    extends Notifier<StudentHomeworkDetailState> {
  StudentHomeworkDetailController(this.target);

  final StudentHomeworkRouteTarget target;
  StudentSessionKey? _activeSessionKey;
  var _generation = 0;

  @override
  StudentHomeworkDetailState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (key == null) {
      _clearOwnership();
      return const StudentHomeworkDetailState();
    }
    if (_activeSessionKey == key) {
      return state;
    }

    _clearOwnership();
    _activeSessionKey = key;
    final generation = _generation;
    scheduleMicrotask(() {
      if (_matchesSession(key) && generation == _generation) {
        unawaited(_load(key));
      }
    });
    return const StudentHomeworkDetailState(
      status: StudentHomeworkDetailStatus.loading,
    );
  }

  void refresh() {
    final key = _activeSessionKey;
    if (key != null && !state.isRequestInFlight && _matchesSession(key)) {
      unawaited(_load(key, retainHomework: true));
    }
  }

  void retry() {
    if (state.status == StudentHomeworkDetailStatus.error) {
      refresh();
    }
  }

  Future<void> _load(
    StudentSessionKey key, {
    bool retainHomework = false,
  }) async {
    final generation = ++_generation;
    final requestTarget = target;
    final retainedHomework = retainHomework ? state.homework : null;
    state = StudentHomeworkDetailState(
      status: retainedHomework == null
          ? StudentHomeworkDetailStatus.loading
          : StudentHomeworkDetailStatus.refreshing,
      homework: retainedHomework,
    );
    try {
      final homework = await ref
          .read(studentHomeworkRepositoryProvider)
          .fetchHomeworkDetail(requestTarget.homeworkId);
      if (!_canPublish(generation, key, requestTarget)) {
        return;
      }
      if (homework.id.toLowerCase() != requestTarget.homeworkId ||
          homework.topic.id.toLowerCase() != requestTarget.topicId) {
        state = const StudentHomeworkDetailState(
          status: StudentHomeworkDetailStatus.notFound,
        );
        return;
      }
      state = StudentHomeworkDetailState(
        status: StudentHomeworkDetailStatus.data,
        homework: homework,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key, requestTarget) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        state = const StudentHomeworkDetailState(
          status: StudentHomeworkDetailStatus.notFound,
        );
        _markTopicHomeworkListStale(key);
        return;
      }
      state = StudentHomeworkDetailState(
        status: StudentHomeworkDetailStatus.error,
        homework: retainedHomework,
        failure: exception.failure,
      );
    }
  }

  bool _canPublish(
    int generation,
    StudentSessionKey key,
    StudentHomeworkRouteTarget requestTarget,
  ) =>
      ref.mounted &&
      generation == _generation &&
      target == requestTarget &&
      _matchesSession(key);

  bool _matchesSession(StudentSessionKey key) =>
      ref.mounted &&
      _activeSessionKey == key &&
      StudentSessionSnapshot.fromSession(
            ref.read(authSessionControllerProvider),
            ref.read(appDeviceSurfaceProvider),
          ).eligibleKey ==
          key;

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }
    _clearOwnership();
    state = const StudentHomeworkDetailState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _markTopicHomeworkListStale(StudentSessionKey key) {
    final provider = studentHomeworkListControllerProvider(target.topicId);
    if (ref.exists(provider)) {
      ref.read(provider.notifier).markAuthoritativeRowsStale(key);
    }
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _generation += 1;
  }
}
