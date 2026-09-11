import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_controller.dart';
import '../domain/student_homework_attempt_route_target.dart';
import 'student_session_key.dart';

enum StudentAttemptRouteOperation { idle, submitting, submitUncertain }

final studentAttemptRouteOperationGateProvider = NotifierProvider.autoDispose
    .family<
      StudentAttemptRouteOperationGate,
      StudentAttemptRouteOperation,
      StudentHomeworkAttemptRouteTarget
    >(StudentAttemptRouteOperationGate.new);

class StudentAttemptRouteOperationGate
    extends Notifier<StudentAttemptRouteOperation> {
  StudentAttemptRouteOperationGate(this.target);

  final StudentHomeworkAttemptRouteTarget target;
  StudentSessionKey? _activeSessionKey;

  @override
  StudentAttemptRouteOperation build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (key != null && key == _activeSessionKey) return state;
    _activeSessionKey = key;
    return StudentAttemptRouteOperation.idle;
  }

  bool claimSubmit() => _transition(
    StudentAttemptRouteOperation.idle,
    StudentAttemptRouteOperation.submitting,
  );

  bool markSubmitUncertain() => _transition(
    StudentAttemptRouteOperation.submitting,
    StudentAttemptRouteOperation.submitUncertain,
  );

  bool claimRetry() => _transition(
    StudentAttemptRouteOperation.submitUncertain,
    StudentAttemptRouteOperation.submitting,
  );

  void release() {
    state = StudentAttemptRouteOperation.idle;
  }

  bool _transition(
    StudentAttemptRouteOperation expected,
    StudentAttemptRouteOperation next,
  ) {
    final key = StudentSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (key == null || key != _activeSessionKey || state != expected) {
      return false;
    }
    state = next;
    return true;
  }
}
