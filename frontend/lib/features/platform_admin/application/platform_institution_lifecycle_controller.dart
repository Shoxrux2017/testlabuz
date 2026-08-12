import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/user_role.dart';
import '../data/platform_institution_detail_repository_impl.dart';
import '../data/platform_institution_lifecycle_repository_impl.dart';
import '../domain/platform_institution_detail.dart';
import '../domain/platform_institution_lifecycle.dart';
import '../domain/platform_institution_lifecycle_repository.dart';
import 'platform_dashboard_controller.dart';
import 'platform_institution_detail_controller.dart';
import 'platform_institution_detail_state.dart';
import 'platform_institution_lifecycle_state.dart';
import 'platform_institution_list_controller.dart';

final platformInstitutionLifecycleControllerProvider = NotifierProvider
    .autoDispose
    .family<
      PlatformInstitutionLifecycleController,
      PlatformInstitutionLifecycleState,
      PlatformInstitutionLifecycleKey
    >((key) => PlatformInstitutionLifecycleController(key));

class PlatformInstitutionLifecycleController
    extends Notifier<PlatformInstitutionLifecycleState> {
  PlatformInstitutionLifecycleController(this.key);

  final PlatformInstitutionLifecycleKey key;

  String? _sessionUserId;
  int? _sessionInstanceId;
  String? _inFlightInstitutionId;
  int _operationGeneration = 0;
  var _isDisposed = false;

  @override
  PlatformInstitutionLifecycleState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _operationGeneration += 1;
      _inFlightInstitutionId = null;
    });

    final session = ref.watch(authSessionControllerProvider);
    final user = session.user;

    if (session.status != AuthSessionStatus.authenticated ||
        user == null ||
        user.id != key.sessionUserId ||
        identityHashCode(user) != key.sessionInstanceId ||
        user.role != UserRole.platformOwner ||
        user.mustChangePassword) {
      _clearSessionState();

      return const PlatformInstitutionLifecycleState.idle();
    }

    if (_sessionUserId == key.sessionUserId &&
        _sessionInstanceId == key.sessionInstanceId) {
      return state;
    }

    _sessionUserId = key.sessionUserId;
    _sessionInstanceId = key.sessionInstanceId;
    _inFlightInstitutionId = null;
    _operationGeneration += 1;

    return const PlatformInstitutionLifecycleState.idle();
  }

  bool beginConfirmation(PlatformInstitutionDetail detail) {
    if (!_hasCurrentSession() ||
        !state.canOpenConfirmation ||
        _inFlightInstitutionId != null ||
        detail.id != key.institutionId) {
      return false;
    }

    _operationGeneration += 1;
    final action = PlatformInstitutionLifecycleAction.forSourceStatus(
      detail.status,
    );
    state = PlatformInstitutionLifecycleState.confirming(
      PlatformInstitutionLifecycleOperation(
        institutionId: detail.id,
        institutionName: detail.name,
        sourceStatus: detail.status,
        action: action,
        sessionUserId: key.sessionUserId,
        sessionInstanceId: key.sessionInstanceId,
        requestGeneration: _operationGeneration,
      ),
    );

    return true;
  }

  void dismiss() {
    if (!state.canDismiss) {
      return;
    }

    _operationGeneration += 1;
    _inFlightInstitutionId = null;
    state = const PlatformInstitutionLifecycleState.idle();
  }

  void acknowledgeRefreshedDetail(PlatformInstitutionDetail detail) {
    final result = state.result;
    final operation = state.operation;
    if (state.status != PlatformInstitutionLifecycleStatus.confirmed ||
        result == null ||
        operation == null ||
        detail.id != operation.institutionId ||
        detail.status != result.status) {
      return;
    }

    state = const PlatformInstitutionLifecycleState.idle();
  }

  Future<void> confirm() async {
    if (!state.canConfirm) {
      return;
    }

    final operation = state.operation;
    if (operation == null || !_operationMatchesCurrentSession(operation)) {
      return;
    }

    _inFlightInstitutionId = operation.institutionId;
    state = PlatformInstitutionLifecycleState.submitting(operation);
    final repository = ref.read(platformInstitutionLifecycleRepositoryProvider);

    try {
      final result = await _sendLifecycleCommand(repository, operation);
      if (!_canComplete(operation)) {
        return;
      }

      ref.invalidate(platformInstitutionListControllerProvider);
      ref.invalidate(platformDashboardControllerProvider);
      state = PlatformInstitutionLifecycleState.confirmed(
        operation: operation,
        result: result,
      );
    } on PlatformInstitutionLifecycleOutcomeUnknownException {
      if (!_canComplete(operation)) {
        return;
      }

      await _reconcileUnknownOutcome(operation);
    } on ApiRequestException catch (exception) {
      if (!_canComplete(operation)) {
        return;
      }

      _reconcileSessionForFailure(exception.failure);
      if (_isConflict(exception.failure)) {
        await _reconcileConflict(operation, exception.failure);
      } else {
        if (_shouldHideStaleDetailForFailure(exception.failure)) {
          _invalidateCurrentDetail(operation);
        }
        state = PlatformInstitutionLifecycleState.definiteFailure(
          operation: operation,
          failure: exception.failure,
          message: _safeFailureMessage(exception.failure),
        );
      }
    } finally {
      if (_inFlightInstitutionId == operation.institutionId) {
        _inFlightInstitutionId = null;
      }
    }
  }

  Future<void> checkStatus() async {
    if (!state.canCheckStatus) {
      return;
    }

    final currentOperation = state.operation;
    if (currentOperation == null ||
        !_operationMatchesCurrentSession(currentOperation)) {
      return;
    }

    final operation = currentOperation;
    _inFlightInstitutionId = operation.institutionId;
    state = PlatformInstitutionLifecycleState.reconciling(operation);

    try {
      await _reconcileUnknownOutcome(operation);
    } finally {
      if (_inFlightInstitutionId == operation.institutionId) {
        _inFlightInstitutionId = null;
      }
    }
  }

  Future<PlatformInstitutionLifecycleResult> _sendLifecycleCommand(
    PlatformInstitutionLifecycleRepository repository,
    PlatformInstitutionLifecycleOperation operation,
  ) {
    return switch (operation.action) {
      PlatformInstitutionLifecycleAction.activate =>
        repository.activateInstitution(operation.institutionId),
      PlatformInstitutionLifecycleAction.deactivate =>
        repository.deactivateInstitution(operation.institutionId),
    };
  }

  Future<void> _reconcileUnknownOutcome(
    PlatformInstitutionLifecycleOperation operation,
  ) async {
    state = PlatformInstitutionLifecycleState.reconciling(operation);
    final repository = ref.read(platformInstitutionDetailRepositoryProvider);

    try {
      final detail = await repository.fetchInstitutionDetail(
        operation.institutionId,
      );
      if (!_canComplete(operation)) {
        return;
      }

      _applyUnknownOutcomeDetail(operation, detail);
    } on ApiRequestException catch (exception) {
      if (!_canComplete(operation)) {
        return;
      }

      _reconcileSessionForFailure(exception.failure);
      state = PlatformInstitutionLifecycleState.unknownOutcome(
        operation: operation,
        failure: exception.failure,
        message:
            'Lifecycle outcome is unknown. Check status before acting again.',
      );
    }
  }

  Future<void> _reconcileConflict(
    PlatformInstitutionLifecycleOperation operation,
    ApiFailure originalFailure,
  ) async {
    state = PlatformInstitutionLifecycleState.reconciling(operation);
    final repository = ref.read(platformInstitutionDetailRepositoryProvider);

    try {
      final detail = await repository.fetchInstitutionDetail(
        operation.institutionId,
      );
      if (!_canComplete(operation)) {
        return;
      }

      if (detail.id != operation.institutionId) {
        state = PlatformInstitutionLifecycleState.definiteFailure(
          operation: operation,
          failure: originalFailure,
          message:
              'The lifecycle command conflicted with current server state.',
        );
        return;
      }

      _invalidateCurrentDetail(operation);
      state = PlatformInstitutionLifecycleState.definiteFailure(
        operation: operation,
        failure: originalFailure,
        currentStatus: detail.status,
        message:
            'The lifecycle command conflicted with current server state. '
            'Current server status is ${detail.status.value}.',
      );
    } on ApiRequestException catch (exception) {
      if (!_canComplete(operation)) {
        return;
      }

      _reconcileSessionForFailure(exception.failure);
      state = PlatformInstitutionLifecycleState.definiteFailure(
        operation: operation,
        failure: originalFailure,
        message: 'The lifecycle command conflicted with current server state.',
      );
    }
  }

  void _applyUnknownOutcomeDetail(
    PlatformInstitutionLifecycleOperation operation,
    PlatformInstitutionDetail detail,
  ) {
    if (detail.id != operation.institutionId) {
      state = PlatformInstitutionLifecycleState.unknownOutcome(
        operation: operation,
        failure: ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Institution status check response did not match request.',
        ),
        message:
            'Lifecycle outcome is unknown. Check status before acting again.',
      );
      return;
    }

    _invalidateCurrentDetail(operation);

    if (detail.status == operation.targetStatus) {
      ref.invalidate(platformInstitutionListControllerProvider);
      ref.invalidate(platformDashboardControllerProvider);
      state = PlatformInstitutionLifecycleState.unknownOutcome(
        operation: operation,
        currentStatus: detail.status,
        message: 'Current server status is ${detail.status.value}.',
      );
      return;
    }

    state = PlatformInstitutionLifecycleState.unknownOutcome(
      operation: operation,
      currentStatus: detail.status,
      message:
          'Current server status is ${detail.status.value}. '
          'No lifecycle change was confirmed.',
    );
  }

  void _invalidateCurrentDetail(
    PlatformInstitutionLifecycleOperation operation,
  ) {
    ref.invalidate(
      platformInstitutionDetailControllerProvider(
        PlatformInstitutionDetailKey(
          sessionUserId: operation.sessionUserId,
          sessionInstanceId: operation.sessionInstanceId,
          institutionId: operation.institutionId,
        ),
      ),
    );
  }

  bool _hasCurrentSession() {
    return _sessionUserId == key.sessionUserId &&
        _sessionInstanceId == key.sessionInstanceId;
  }

  bool _operationMatchesCurrentSession(
    PlatformInstitutionLifecycleOperation operation,
  ) {
    return operation.sessionUserId == _sessionUserId &&
        operation.sessionInstanceId == _sessionInstanceId &&
        operation.institutionId == key.institutionId;
  }

  bool _canComplete(PlatformInstitutionLifecycleOperation operation) {
    return !_isDisposed &&
        operation.requestGeneration == _operationGeneration &&
        _operationMatchesCurrentSession(operation);
  }

  void _clearSessionState() {
    _sessionUserId = null;
    _sessionInstanceId = null;
    _inFlightInstitutionId = null;
    _operationGeneration += 1;
  }

  bool _isConflict(ApiFailure failure) {
    return failure.statusCode == 409;
  }

  bool _shouldHideStaleDetailForFailure(ApiFailure failure) {
    return (failure.statusCode == 404 &&
            failure.serverCode == ApiErrorCodes.resourceNotFound) ||
        (failure.statusCode == 403 &&
            failure.serverCode == ApiErrorCodes.forbidden);
  }

  String _safeFailureMessage(ApiFailure failure) {
    return switch (failure.serverCode) {
      ApiErrorCodes.authenticationRequired => 'Please sign in again.',
      ApiErrorCodes.passwordChangeRequired =>
        'Password change is required before institution lifecycle actions.',
      ApiErrorCodes.userInactive => 'This account is inactive.',
      ApiErrorCodes.institutionInactive => 'This institution is inactive.',
      ApiErrorCodes.forbidden =>
        'You do not have permission to change this institution status.',
      ApiErrorCodes.resourceNotFound => 'The institution could not be found.',
      ApiErrorCodes.validationFailed =>
        'The institution lifecycle request did not match the API contract.',
      ApiErrorCodes.serverError =>
        'The institution status could not be changed. No change was confirmed.',
      _ => switch (failure.kind) {
        ApiFailureKind.connection =>
          'Could not reach the server. No lifecycle change was confirmed.',
        ApiFailureKind.timeout =>
          'The institution lifecycle request timed out. No change was confirmed.',
        ApiFailureKind.invalidResponse =>
          'The server returned an unexpected institution lifecycle response.',
        ApiFailureKind.cancelled =>
          'The institution lifecycle request was cancelled.',
        ApiFailureKind.unknown ||
        ApiFailureKind.server ||
        ApiFailureKind.validation =>
          'The institution status could not be changed. No change was confirmed.',
      },
    };
  }

  void _reconcileSessionForFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code == ApiErrorCodes.authenticationRequired ||
        code == ApiErrorCodes.passwordChangeRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
  }
}
