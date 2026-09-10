import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_homework_attempt_repository_impl.dart';
import '../domain/student_homework.dart';
import '../domain/student_homework_attempt.dart';
import '../domain/student_homework_attempt_route_target.dart';
import '../domain/student_homework_route_target.dart';
import 'student_homework_attempt_state.dart';
import 'student_homework_detail_controller.dart';
import 'student_homework_list_controller.dart';
import 'student_session_key.dart';

final studentHomeworkAttemptControllerProvider = NotifierProvider.autoDispose
    .family<
      StudentHomeworkAttemptController,
      StudentHomeworkAttemptState,
      StudentHomeworkAttemptRouteTarget
    >(StudentHomeworkAttemptController.new);

class StudentHomeworkAttemptController
    extends Notifier<StudentHomeworkAttemptState> {
  StudentHomeworkAttemptController(this.target);

  final StudentHomeworkAttemptRouteTarget target;
  StudentSessionKey? _activeSessionKey;
  var _generation = 0;

  @override
  StudentHomeworkAttemptState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (key == null) {
      _clearOwnership();
      return const StudentHomeworkAttemptState();
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
    return const StudentHomeworkAttemptState(
      status: StudentHomeworkAttemptLoadStatus.loading,
    );
  }

  void refresh() {
    final key = _activeSessionKey;
    if (key != null && !state.isRequestInFlight && _matchesSession(key)) {
      unawaited(_load(key, retainAttempt: true));
    }
  }

  void retry() {
    if (state.status == StudentHomeworkAttemptLoadStatus.error) {
      refresh();
    }
  }

  bool acceptAuthoritativeTerminalAttempt(StudentHomeworkAttempt attempt) {
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        !isCanonicalStudentAttemptId(attempt.id) ||
        !isCanonicalStudentAttemptId(target.attemptId) ||
        !isCanonicalStudentHomeworkId(attempt.assessmentId) ||
        !isCanonicalStudentHomeworkId(target.homeworkId) ||
        attempt.id.toLowerCase() != target.attemptId.toLowerCase() ||
        attempt.assessmentId.toLowerCase() != target.homeworkId.toLowerCase() ||
        attempt.status == StudentHomeworkAttemptStatus.inProgress) {
      return false;
    }
    _generation += 1;
    state = StudentHomeworkAttemptState(
      status: StudentHomeworkAttemptLoadStatus.data,
      attempt: attempt,
    );
    return true;
  }

  Future<void> _load(
    StudentSessionKey key, {
    bool retainAttempt = false,
  }) async {
    final generation = ++_generation;
    final requestTarget = target;
    final retainedAttempt = retainAttempt ? state.attempt : null;
    state = StudentHomeworkAttemptState(
      status: retainedAttempt == null
          ? StudentHomeworkAttemptLoadStatus.loading
          : StudentHomeworkAttemptLoadStatus.refreshing,
      attempt: retainedAttempt,
    );
    try {
      final attempt = await ref
          .read(studentHomeworkAttemptRepositoryProvider)
          .fetchAttempt(requestTarget.attemptId);
      if (!_canPublish(generation, key, requestTarget)) {
        return;
      }
      if (attempt.id.toLowerCase() != requestTarget.attemptId ||
          attempt.assessmentId.toLowerCase() != requestTarget.homeworkId) {
        state = const StudentHomeworkAttemptState(
          status: StudentHomeworkAttemptLoadStatus.notFound,
        );
        return;
      }
      state = StudentHomeworkAttemptState(
        status: StudentHomeworkAttemptLoadStatus.data,
        attempt: attempt,
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key, requestTarget) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      if (exception.failure.statusCode == 404 &&
          exception.failure.serverCode == ApiErrorCodes.resourceNotFound) {
        state = const StudentHomeworkAttemptState(
          status: StudentHomeworkAttemptLoadStatus.notFound,
        );
        _reconcileHomework(key);
        return;
      }
      state = StudentHomeworkAttemptState(
        status: StudentHomeworkAttemptLoadStatus.error,
        attempt: retainedAttempt,
        failure: exception.failure,
      );
    }
  }

  void _reconcileHomework(StudentSessionKey key) {
    ref.invalidate(
      studentHomeworkDetailControllerProvider(
        StudentHomeworkRouteTarget(
          topicId: target.topicId,
          homeworkId: target.homeworkId,
        ),
      ),
    );
    final listProvider = studentHomeworkListControllerProvider(target.topicId);
    if (ref.exists(listProvider)) {
      ref.read(listProvider.notifier).markAuthoritativeRowsStale(key);
    }
  }

  bool _canPublish(
    int generation,
    StudentSessionKey key,
    StudentHomeworkAttemptRouteTarget requestTarget,
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
    state = const StudentHomeworkAttemptState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _generation += 1;
  }
}
