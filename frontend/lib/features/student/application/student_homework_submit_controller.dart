import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/idempotency_key_generator.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_homework_attempt_repository_impl.dart';
import '../domain/student_homework.dart';
import '../domain/student_homework_attempt.dart';
import '../domain/student_homework_attempt_route_target.dart';
import '../domain/student_homework_route_target.dart';
import 'student_attempt_route_operation_gate.dart';
import 'student_homework_attempt_controller.dart';
import 'student_homework_detail_controller.dart';
import 'student_homework_list_controller.dart';
import 'student_homework_submit_readiness.dart';
import 'student_homework_submit_state.dart';
import 'student_session_key.dart';

final studentHomeworkSubmitControllerProvider = NotifierProvider.autoDispose
    .family<
      StudentHomeworkSubmitController,
      StudentHomeworkSubmitState,
      StudentHomeworkAttemptRouteTarget
    >(StudentHomeworkSubmitController.new);

class StudentHomeworkSubmitController
    extends Notifier<StudentHomeworkSubmitState> {
  StudentHomeworkSubmitController(this.target);

  final StudentHomeworkAttemptRouteTarget target;
  StudentSessionKey? _activeSessionKey;
  String? _pendingIdempotencyKey;
  var _logicalGeneration = 0;
  var _resolutionGeneration = 0;

  @override
  StudentHomeworkSubmitState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    // Keep route authority alive without resolving this operation from an
    // unrelated parent refresh or rebuilding on local editor state changes.
    ref.listen(studentHomeworkSubmitReadinessProvider(target), (_, _) {});
    if (key != null && key == _activeSessionKey) return state;
    _invalidateLogicalOperation();
    _activeSessionKey = key;
    return const StudentHomeworkSubmitState();
  }

  StudentAttemptRouteOperationGate get _gate =>
      ref.read(studentAttemptRouteOperationGateProvider(target).notifier);

  Future<void> submitConfirmed(
    StudentHomeworkSubmitReadyToken capturedReadyToken,
  ) async {
    if (state.status != StudentHomeworkSubmitStatus.idle &&
        state.status != StudentHomeworkSubmitStatus.failure) {
      return;
    }
    final current = ref
        .read(studentHomeworkSubmitReadinessProvider(target))
        .readyToken;
    final key = _activeSessionKey;
    if (current == null ||
        !capturedReadyToken.matches(current) ||
        key == null ||
        current.sessionKey != key ||
        current.target != target ||
        !_matchesSession(key)) {
      return;
    }
    _pendingIdempotencyKey = ref
        .read(idempotencyKeyGeneratorProvider)
        .generate();
    if (!_gate.claimSubmit()) {
      _pendingIdempotencyKey = null;
      return;
    }
    _logicalGeneration += 1;
    await _post(_claimResolution(key));
  }

  Future<void> retrySubmission() async {
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        _pendingIdempotencyKey == null ||
        state.status != StudentHomeworkSubmitStatus.uncertain ||
        !_gate.claimRetry()) {
      return;
    }
    await _post(_claimResolution(key));
  }

  _SubmitResolution _claimResolution(StudentSessionKey key) =>
      _SubmitResolution(
        sessionKey: key,
        target: target,
        idempotencyKey: _pendingIdempotencyKey!,
        logicalGeneration: _logicalGeneration,
        resolutionGeneration: ++_resolutionGeneration,
      );

  Future<void> _post(_SubmitResolution operation) async {
    state = const StudentHomeworkSubmitState(
      status: StudentHomeworkSubmitStatus.submitting,
    );
    try {
      final result = await ref
          .read(studentHomeworkAttemptRepositoryProvider)
          .submitAttempt(
            operation.target.attemptId,
            operation.target.homeworkId,
            operation.idempotencyKey,
          );
      if (!_owns(operation)) return;
      if (!_validExplicitSubmit(result.attempt)) throw _invalidResponse();
      _adoptTerminal(operation, result.attempt, completed: true);
    } on ApiRequestException catch (exception) {
      if (!_owns(operation) || _clearForSessionFailure(exception.failure)) {
        return;
      }
      if (_isUncertain(exception.failure)) {
        _publishUncertain(exception.failure);
      } else {
        _resolveFailure(operation.sessionKey, exception.failure);
      }
    }
  }

  Future<void> checkCurrentAttempt() async {
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        _pendingIdempotencyKey == null ||
        state.status != StudentHomeworkSubmitStatus.uncertain ||
        ref.read(studentAttemptRouteOperationGateProvider(target)) !=
            StudentAttemptRouteOperation.submitUncertain) {
      return;
    }
    final operation = _claimResolution(key);
    state = const StudentHomeworkSubmitState(
      status: StudentHomeworkSubmitStatus.checking,
    );
    try {
      final attempt = await ref
          .read(studentHomeworkAttemptRepositoryProvider)
          .fetchAttempt(target.attemptId);
      if (!_owns(operation)) return;
      if (!_matchesAttempt(attempt)) throw _invalidResponse();
      if (attempt.status == StudentHomeworkAttemptStatus.inProgress) {
        _publishUncertain();
        return;
      }
      if (attempt.finalizationReason == null || attempt.finalizedAt == null) {
        throw _invalidResponse();
      }
      if (attempt.finalizationReason ==
              StudentHomeworkAttemptFinalizationReason.studentSubmit &&
          !_validExplicitSubmit(attempt)) {
        throw _invalidResponse();
      }
      _adoptTerminal(operation, attempt, completed: false);
    } on ApiRequestException catch (exception) {
      if (!_owns(operation) || _clearForSessionFailure(exception.failure)) {
        return;
      }
      _publishUncertain(exception.failure);
    }
  }

  void _adoptTerminal(
    _SubmitResolution operation,
    StudentHomeworkAttempt attempt, {
    required bool completed,
  }) {
    if (!_owns(operation)) return;
    // Invalidate all resolution completions before publishing terminal authority.
    // The gate stays held until the parent has accepted the terminal resource.
    _resolutionGeneration += 1;
    final accepted = ref
        .read(studentHomeworkAttemptControllerProvider(target).notifier)
        .acceptAuthoritativeTerminalAttempt(attempt);
    if (!accepted) {
      if (_matchesLogicalOperation(operation)) {
        _publishUncertain(_invalidResponse().failure);
      }
      return;
    }
    if (!_matchesLogicalOperation(operation)) return;
    _pendingIdempotencyKey = null;
    final reason = completed
        ? null
        : switch (attempt.finalizationReason!) {
            StudentHomeworkAttemptFinalizationReason.studentSubmit =>
              StudentHomeworkSubmitTerminalReconciliationReason
                  .studentSubmitAlreadyTerminal,
            StudentHomeworkAttemptFinalizationReason.homeworkDeadline =>
              StudentHomeworkSubmitTerminalReconciliationReason
                  .homeworkDeadlineAutoFinalized,
            StudentHomeworkAttemptFinalizationReason.taskClosed =>
              StudentHomeworkSubmitTerminalReconciliationReason
                  .taskClosedAutoFinalized,
          };
    state = StudentHomeworkSubmitState(
      status: completed
          ? StudentHomeworkSubmitStatus.completed
          : StudentHomeworkSubmitStatus.reconciledTerminal,
      terminalReconciliationReason: reason,
      notice: completed
          ? 'Attempt submitted successfully.'
          : reason ==
                StudentHomeworkSubmitTerminalReconciliationReason
                    .studentSubmitAlreadyTerminal
          ? 'This Attempt is already submitted.'
          : null,
    );
    _gate.release();
    _refreshHomework(operation.sessionKey, includeList: true);
  }

  void _publishUncertain([ApiFailure? failure]) {
    _gate.markSubmitUncertain();
    state = StudentHomeworkSubmitState(
      status: StudentHomeworkSubmitStatus.uncertain,
      failure: failure,
    );
  }

  void _resolveFailure(StudentSessionKey key, ApiFailure failure) {
    _invalidateLogicalOperation();
    // Revoke parent mutation authority before exposing a released gate/failure.
    // A synchronous listener must not confirm against the rejected snapshot.
    ref
        .read(studentHomeworkAttemptControllerProvider(target).notifier)
        .refresh();
    _gate.release();
    state = StudentHomeworkSubmitState(
      status: StudentHomeworkSubmitStatus.failure,
      failure: failure,
      notice: switch (failure.serverCode) {
        ApiErrorCodes.deadlinePassed => 'The Homework deadline has passed.',
        ApiErrorCodes.attemptNotEditable =>
          'This Attempt is no longer editable.',
        ApiErrorCodes.taskNotActive ||
        ApiErrorCodes.taskClosed ||
        ApiErrorCodes.taskArchived =>
          'This Homework is no longer available for submission.',
        ApiErrorCodes.idempotencyKeyReused =>
          'The Attempt could not be submitted safely. Check the current Attempt and try again if it is still editable.',
        ApiErrorCodes.validationFailed =>
          'The submission request could not be validated. Refresh and try again.',
        ApiErrorCodes.resourceNotFound =>
          'This Attempt is no longer available.',
        _ =>
          'The Attempt could not be submitted. Check the current Attempt and try again.',
      },
    );
    switch (failure.serverCode) {
      case ApiErrorCodes.deadlinePassed:
      case ApiErrorCodes.resourceNotFound:
        _refreshHomework(key, includeList: true);
      case ApiErrorCodes.taskNotActive:
      case ApiErrorCodes.taskClosed:
      case ApiErrorCodes.taskArchived:
        _refreshHomework(key);
    }
  }

  void _refreshHomework(StudentSessionKey key, {bool includeList = false}) {
    ref
        .read(
          studentHomeworkDetailControllerProvider(
            StudentHomeworkRouteTarget(
              topicId: target.topicId,
              homeworkId: target.homeworkId,
            ),
          ).notifier,
        )
        .refresh();
    final list = studentHomeworkListControllerProvider(target.topicId);
    if (includeList && ref.exists(list)) {
      ref.read(list.notifier).markAuthoritativeRowsStale(key);
    }
  }

  void clearLocalState() {
    _invalidateLogicalOperation();
    _gate.release();
    state = const StudentHomeworkSubmitState();
  }

  bool _matchesAttempt(StudentHomeworkAttempt attempt) =>
      isCanonicalStudentAttemptId(attempt.id) &&
      isCanonicalStudentHomeworkId(attempt.assessmentId) &&
      attempt.id.toLowerCase() == target.attemptId &&
      attempt.assessmentId.toLowerCase() == target.homeworkId;

  bool _validExplicitSubmit(StudentHomeworkAttempt attempt) =>
      _matchesAttempt(attempt) &&
      attempt.status != StudentHomeworkAttemptStatus.inProgress &&
      attempt.finalizationReason ==
          StudentHomeworkAttemptFinalizationReason.studentSubmit &&
      attempt.submittedAt != null &&
      attempt.finalizedAt == attempt.submittedAt;

  bool _owns(_SubmitResolution operation) =>
      _matchesLogicalOperation(operation) &&
      operation.resolutionGeneration == _resolutionGeneration;

  bool _matchesLogicalOperation(_SubmitResolution operation) =>
      ref.mounted &&
      operation.target == target &&
      operation.logicalGeneration == _logicalGeneration &&
      operation.idempotencyKey == _pendingIdempotencyKey &&
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
    state = const StudentHomeworkSubmitState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _invalidateLogicalOperation() {
    _pendingIdempotencyKey = null;
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
    required this.target,
    required this.idempotencyKey,
    required this.logicalGeneration,
    required this.resolutionGeneration,
  });
  final StudentSessionKey sessionKey;
  final StudentHomeworkAttemptRouteTarget target;
  final String idempotencyKey;
  final int logicalGeneration;
  final int resolutionGeneration;
}
