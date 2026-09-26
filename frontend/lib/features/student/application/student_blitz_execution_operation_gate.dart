import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_controller.dart';
import '../domain/student_blitz_execution_target.dart';
import 'student_session_key.dart';

enum StudentBlitzExecutionOperation {
  idle,
  submitting,
  submitUncertain,

  /// A rejected Submit is re-reading the current Attempt.
  terminalReconciliation,
}

/// Route-session gate for one Blitz Attempt: Submit claims it, and answer or
/// file writes start only while it is idle. It is not a global Student lock.
final studentBlitzExecutionOperationGateProvider = NotifierProvider.autoDispose
    .family<
      StudentBlitzExecutionOperationGate,
      StudentBlitzExecutionOperation,
      StudentBlitzExecutionTarget
    >(StudentBlitzExecutionOperationGate.new);

class StudentBlitzExecutionOperationGate
    extends Notifier<StudentBlitzExecutionOperation> {
  StudentBlitzExecutionOperationGate(this.target);

  final StudentBlitzExecutionTarget target;
  StudentSessionKey? _activeSessionKey;

  @override
  StudentBlitzExecutionOperation build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (!ref.isRefresh && key != null && key == _activeSessionKey) {
      return state;
    }
    _activeSessionKey = key;
    return StudentBlitzExecutionOperation.idle;
  }

  bool claimSubmit() => _transition(
    StudentBlitzExecutionOperation.idle,
    StudentBlitzExecutionOperation.submitting,
  );

  bool markSubmitUncertain() => _transition(
    StudentBlitzExecutionOperation.submitting,
    StudentBlitzExecutionOperation.submitUncertain,
  );

  bool claimRetry() => _transition(
    StudentBlitzExecutionOperation.submitUncertain,
    StudentBlitzExecutionOperation.submitting,
  );

  bool markTerminalReconciliation() => _transition(
    StudentBlitzExecutionOperation.submitting,
    StudentBlitzExecutionOperation.terminalReconciliation,
  );

  void release() {
    state = StudentBlitzExecutionOperation.idle;
  }

  bool _transition(
    StudentBlitzExecutionOperation expected,
    StudentBlitzExecutionOperation next,
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
