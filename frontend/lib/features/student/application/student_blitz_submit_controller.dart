import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/idempotency_key_generator.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_blitz_attempt_repository_impl.dart';
import '../domain/student_blitz_attempt.dart';
import '../domain/student_blitz_execution_target.dart';
import '../domain/student_blitz_submit.dart';
import 'student_blitz_execution_controller.dart';
import 'student_blitz_execution_operation_gate.dart';
import 'student_blitz_execution_state.dart';
import 'student_blitz_submit_readiness.dart';
import 'student_blitz_submit_state.dart';
import 'student_session_key.dart';

final studentBlitzSubmitControllerProvider = NotifierProvider.autoDispose
    .family<
      StudentBlitzSubmitController,
      StudentBlitzSubmitState,
      StudentBlitzExecutionTarget
    >(StudentBlitzSubmitController.new);

/// Explicit, idempotent final Submit of one Blitz execution Attempt.
///
/// One logical Submit owns one key. An uncertain outcome keeps it for a
/// same-key Retry; a check re-reads the Attempt only by replaying the
/// completed Start request, never with a new Start or Submit key.
class StudentBlitzSubmitController extends Notifier<StudentBlitzSubmitState> {
  StudentBlitzSubmitController(this.target);

  final StudentBlitzExecutionTarget target;
  StudentSessionKey? _activeSessionKey;
  String? _pendingSubmitIdempotencyKey;
  var _logicalGeneration = 0;
  var _resolutionGeneration = 0;

  @override
  StudentBlitzSubmitState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    // Keep route authority alive without rebuilding on local editor changes.
    ref.listen(studentBlitzSubmitReadinessProvider(target), (_, _) {});
    ref.listen(
      studentBlitzExecutionControllerProvider(target.routeTarget),
      _onExecution,
    );
    if (!ref.isRefresh && key != null && key == _activeSessionKey) {
      return state;
    }
    _invalidateLogicalOperation();
    _activeSessionKey = key;
    return const StudentBlitzSubmitState();
  }

  StudentBlitzExecutionOperationGate get _gate =>
      ref.read(studentBlitzExecutionOperationGateProvider(target).notifier);

  StudentBlitzExecutionController get _execution => ref.read(
    studentBlitzExecutionControllerProvider(target.routeTarget).notifier,
  );

  /// Submits once for the confirmation shown for [capturedReadyToken]. If
  /// anything changed while the dialog was open, nothing is sent.
  Future<void> submitConfirmed(
    StudentBlitzSubmitReadyToken capturedReadyToken,
  ) async {
    if (state.status != StudentBlitzSubmitStatus.idle &&
        state.status != StudentBlitzSubmitStatus.failure) {
      return;
    }
    final current = ref
        .read(studentBlitzSubmitReadinessProvider(target))
        .readyToken;
    final key = _activeSessionKey;
    if (current == null ||
        !capturedReadyToken.matches(current) ||
        key == null ||
        current.sessionKey != key ||
        current.target != target ||
        !_matchesSession(key)) {
      state = StudentBlitzSubmitState(
        status: state.status,
        failure: state.failure,
        notice:
            'The attempt changed while the confirmation was open. '
            'Review the current attempt before submitting.',
      );
      return;
    }
    if (!_gate.claimSubmit()) return;
    final write = _execution.beginWrite();
    if (write == null) {
      _gate.release();
      return;
    }
    // The key exists only after confirmation, readiness and the gate claim.
    _pendingSubmitIdempotencyKey = ref
        .read(idempotencyKeyGeneratorProvider)
        .generate();
    _logicalGeneration += 1;
    await _post(
      _claimResolution(key),
      StudentBlitzSubmitResponseExpectation.fresh,
      write,
    );
  }

  /// Resends the same logical Submit with the same key.
  Future<void> retrySubmission() async {
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        _pendingSubmitIdempotencyKey == null ||
        state.status != StudentBlitzSubmitStatus.uncertain ||
        !ref
            .read(studentBlitzExecutionControllerProvider(target.routeTarget))
            .isExecuting ||
        !_gate.claimRetry()) {
      return;
    }
    final write = _execution.beginWrite();
    if (write == null) {
      _gate.markSubmitUncertain();
      return;
    }
    await _post(
      _claimResolution(key),
      StudentBlitzSubmitResponseExpectation.completedReplay,
      write,
    );
  }

  /// Re-reads the current Attempt while the Submit outcome is unconfirmed.
  Future<void> checkCurrentAttempt() async {
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        _pendingSubmitIdempotencyKey == null ||
        state.status != StudentBlitzSubmitStatus.uncertain ||
        ref.read(studentBlitzExecutionOperationGateProvider(target)) !=
            StudentBlitzExecutionOperation.submitUncertain) {
      return;
    }
    final operation = _claimResolution(key);
    state = const StudentBlitzSubmitState(
      status: StudentBlitzSubmitStatus.checking,
    );
    final outcome = await _execution.refreshCurrentAttempt();
    // A terminal or dropped execution already resolved this operation.
    if (!_owns(operation)) return;
    final execution = ref.read(
      studentBlitzExecutionControllerProvider(target.routeTarget),
    );
    switch (outcome) {
      case StudentBlitzAttemptReplayOutcome.terminal:
        _resolveTerminal(execution.attempt!);
      case StudentBlitzAttemptReplayOutcome.active:
        // Still in progress: the Submit may not have committed yet.
        _publishUncertain();
      case StudentBlitzAttemptReplayOutcome.failed ||
          StudentBlitzAttemptReplayOutcome.unavailable:
        _publishUncertain(execution.failure);
    }
  }

  /// Leaving discards the retry key; nothing is sent.
  void clearLocalState() {
    _invalidateLogicalOperation();
    _gate.release();
    state = const StudentBlitzSubmitState();
  }

  _SubmitResolution _claimResolution(StudentSessionKey key) =>
      _SubmitResolution(
        sessionKey: key,
        idempotencyKey: _pendingSubmitIdempotencyKey!,
        logicalGeneration: _logicalGeneration,
        resolutionGeneration: ++_resolutionGeneration,
      );

  Future<void> _post(
    _SubmitResolution operation,
    StudentBlitzSubmitResponseExpectation expectation,
    Object write,
  ) async {
    // Captured now: the write must end even if this route is gone meanwhile.
    final execution = _execution;
    state = const StudentBlitzSubmitState(
      status: StudentBlitzSubmitStatus.submitting,
    );
    try {
      final result = await ref
          .read(studentBlitzAttemptRepositoryProvider)
          .submitAttempt(
            target.attemptId,
            target.routeTarget.blitzId,
            operation.idempotencyKey,
            expectation: expectation,
          );
      if (!_owns(operation)) return;
      if (!_isStudentSubmit(result.attempt, expectation)) {
        throw _invalidResponse();
      }
      _adoptSubmitted(operation, result.attempt);
    } on ApiRequestException catch (exception) {
      if (!_owns(operation) || _clearForSessionFailure(exception.failure)) {
        return;
      }
      if (_isUncertain(exception.failure)) {
        _publishUncertain(exception.failure);
      } else {
        _resolveRejection(exception.failure);
      }
    } catch (_) {
      // The POST may have committed; keep the key for a same-key Retry.
      if (_owns(operation)) {
        _publishUncertain(
          ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Blitz submission failure.',
          ),
        );
      }
    } finally {
      // Ends the write only after a success was adopted, so a pending
      // expiry replay never races the server's own Submit result.
      execution.endWrite(write);
    }
  }

  void _adoptSubmitted(
    _SubmitResolution operation,
    StudentBlitzAttempt attempt,
  ) {
    // Invalidate other completions before publishing terminal authority.
    _resolutionGeneration += 1;
    if (!_execution.acceptSubmittedAttempt(attempt)) {
      if (_matchesLogicalOperation(operation)) {
        _publishUncertain(_invalidResponse().failure);
      }
      return;
    }
    if (!_matchesLogicalOperation(operation)) return;
    _pendingSubmitIdempotencyKey = null;
    state = StudentBlitzSubmitState(
      status: StudentBlitzSubmitStatus.completed,
      // A later-stage status confirms the original Submit without implying
      // that this device reviewed or checked anything.
      notice: attempt.status == StudentBlitzAttemptStatus.submitted
          ? 'Blitz submitted successfully.'
          : 'Blitz submission confirmed.',
    );
    _gate.release();
  }

  void _publishUncertain([ApiFailure? failure]) {
    _gate.markSubmitUncertain();
    state = StudentBlitzSubmitState(
      status: StudentBlitzSubmitStatus.uncertain,
      failure: failure,
    );
  }

  /// A definite rejection stores no Submit: the key is dropped and the
  /// current Attempt is re-read before any new Submit is possible.
  void _resolveRejection(ApiFailure failure) {
    _invalidateLogicalOperation();
    final generation = _logicalGeneration;
    final code = failure.serverCode;
    final terminalConflict =
        code == ApiErrorCodes.blitzTimeExpired ||
        code == ApiErrorCodes.attemptNotEditable ||
        code == ApiErrorCodes.blitzNotActive;
    if (terminalConflict) {
      _gate.markTerminalReconciliation();
    } else {
      _gate.release();
    }
    state = StudentBlitzSubmitState(
      status: StudentBlitzSubmitStatus.failure,
      failure: failure,
      notice: _rejectionNotice(code),
    );
    unawaited(
      _reconcileRejection(failure, generation, holdsGate: terminalConflict),
    );
  }

  Future<void> _reconcileRejection(
    ApiFailure failure,
    int generation, {
    required bool holdsGate,
  }) async {
    final execution = _execution;
    final outcome = await execution.reconcileAfterRejectedWrite(failure);
    // A terminal or dropped execution already resolved this rejection.
    if (!ref.mounted || generation != _logicalGeneration) return;
    if (holdsGate &&
        ref.read(studentBlitzExecutionOperationGateProvider(target)) ==
            StudentBlitzExecutionOperation.terminalReconciliation) {
      _gate.release();
    }
    switch (outcome) {
      case StudentBlitzAttemptReplayOutcome.terminal:
        final attempt = ref
            .read(studentBlitzExecutionControllerProvider(target.routeTarget))
            .attempt;
        if (attempt != null) _resolveTerminal(attempt);
      case StudentBlitzAttemptReplayOutcome.active:
        // The server refused a terminal-only Submit yet reports the Attempt
        // in progress; stay read-only until an explicit check confirms it.
        if (holdsGate) execution.requireReconciliation(failure);
      case StudentBlitzAttemptReplayOutcome.failed:
        if (failure.serverCode == ApiErrorCodes.blitzTimeExpired) {
          state = StudentBlitzSubmitState(
            status: StudentBlitzSubmitStatus.failure,
            failure: failure,
            notice:
                'Time has expired.\n'
                'Reconnect and refresh to confirm the final attempt state.',
          );
        }
      case StudentBlitzAttemptReplayOutcome.unavailable:
        return;
    }
  }

  void _onExecution(
    StudentBlitzExecutionState? _,
    StudentBlitzExecutionState next,
  ) {
    if (next.status == StudentBlitzExecutionStatus.none) {
      if (state.status != StudentBlitzSubmitStatus.idle ||
          _pendingSubmitIdempotencyKey != null) {
        clearLocalState();
      }
      return;
    }
    final attempt = next.attempt;
    // An in-flight Submit resolves itself; otherwise a terminal Attempt
    // resolves any unconfirmed Submit or rejection still in progress.
    if (!next.isTerminal ||
        attempt == null ||
        state.status == StudentBlitzSubmitStatus.submitting ||
        (_pendingSubmitIdempotencyKey == null &&
            ref.read(studentBlitzExecutionOperationGateProvider(target)) ==
                StudentBlitzExecutionOperation.idle)) {
      return;
    }
    _resolveTerminal(attempt);
  }

  /// The Attempt is final. Which key or device finalized it is unknown, so
  /// no Submit success is claimed here.
  void _resolveTerminal(StudentBlitzAttempt attempt) {
    _invalidateLogicalOperation();
    _gate.release();
    state = StudentBlitzSubmitState(
      status: StudentBlitzSubmitStatus.reconciledTerminal,
      notice:
          attempt.finalizationReason ==
              StudentBlitzAttemptFinalizationReason.studentSubmit
          ? 'This Blitz attempt is already submitted.'
          : null,
    );
  }

  String _rejectionNotice(String? code) => switch (code) {
    ApiErrorCodes.blitzTimeExpired => 'The Blitz time has expired.',
    ApiErrorCodes.attemptNotEditable =>
      'This Blitz attempt is no longer editable.',
    ApiErrorCodes.blitzNotActive => 'This Blitz is no longer active.',
    ApiErrorCodes.idempotencyKeyReused =>
      'The Blitz could not be submitted safely.\n'
          'Check the current attempt before trying again.',
    ApiErrorCodes.validationFailed =>
      'The submission request could not be validated.\n'
          'Refresh the current Blitz and try again if it remains editable.',
    ApiErrorCodes.resourceNotFound =>
      'This Blitz attempt is no longer available.',
    _ =>
      'The Blitz could not be submitted. '
          'Check the current attempt and try again.',
  };

  /// Defense in depth over the strict DTO: only the original Student Submit
  /// lineage is a Submit success.
  bool _isStudentSubmit(
    StudentBlitzAttempt attempt,
    StudentBlitzSubmitResponseExpectation expectation,
  ) {
    final submittedAt = attempt.submittedAt;
    final finalizedAt = attempt.finalizedAt;
    final statusAccepted = switch (expectation) {
      StudentBlitzSubmitResponseExpectation.fresh =>
        attempt.status == StudentBlitzAttemptStatus.submitted,
      StudentBlitzSubmitResponseExpectation.completedReplay =>
        attempt.status == StudentBlitzAttemptStatus.submitted ||
            attempt.status == StudentBlitzAttemptStatus.waitingForReview ||
            attempt.status == StudentBlitzAttemptStatus.checked,
    };
    return statusAccepted &&
        attempt.id.toLowerCase() == target.attemptId &&
        attempt.assessmentId.toLowerCase() == target.routeTarget.blitzId &&
        attempt.finalizationReason ==
            StudentBlitzAttemptFinalizationReason.studentSubmit &&
        submittedAt != null &&
        finalizedAt != null &&
        finalizedAt.isAtSameMomentAs(submittedAt) &&
        finalizedAt.isBefore(attempt.deadlineAt);
  }

  bool _owns(_SubmitResolution operation) =>
      _matchesLogicalOperation(operation) &&
      operation.resolutionGeneration == _resolutionGeneration;

  bool _matchesLogicalOperation(_SubmitResolution operation) =>
      ref.mounted &&
      operation.logicalGeneration == _logicalGeneration &&
      operation.idempotencyKey == _pendingSubmitIdempotencyKey &&
      _matchesSession(operation.sessionKey);

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
    _invalidateLogicalOperation();
    _activeSessionKey = null;
    _gate.release();
    state = const StudentBlitzSubmitState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _invalidateLogicalOperation() {
    _pendingSubmitIdempotencyKey = null;
    _logicalGeneration += 1;
    _resolutionGeneration += 1;
  }

  bool _isUncertain(ApiFailure failure) => switch (failure.kind) {
    ApiFailureKind.connection ||
    ApiFailureKind.timeout ||
    ApiFailureKind.cancelled ||
    ApiFailureKind.invalidResponse ||
    ApiFailureKind.unknown => true,
    ApiFailureKind.server || ApiFailureKind.validation =>
      failure.statusCode == null ||
          failure.statusCode! < 400 ||
          failure.statusCode! >= 500,
  };

  ApiRequestException _invalidResponse() => ApiRequestException(
    ApiFailure.local(
      kind: ApiFailureKind.invalidResponse,
      message: 'The submission response could not be confirmed.',
    ),
  );
}

class _SubmitResolution {
  const _SubmitResolution({
    required this.sessionKey,
    required this.idempotencyKey,
    required this.logicalGeneration,
    required this.resolutionGeneration,
  });
  final StudentSessionKey sessionKey;
  final String idempotencyKey;
  final int logicalGeneration;
  final int resolutionGeneration;
}
