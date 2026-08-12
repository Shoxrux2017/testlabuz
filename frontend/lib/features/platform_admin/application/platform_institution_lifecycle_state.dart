import '../../../core/network/api_failure.dart';
import '../domain/platform_institution.dart';
import '../domain/platform_institution_lifecycle.dart';

class PlatformInstitutionLifecycleKey {
  const PlatformInstitutionLifecycleKey({
    required this.sessionUserId,
    required this.sessionInstanceId,
    required this.institutionId,
  });

  final String sessionUserId;
  final int sessionInstanceId;
  final String institutionId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlatformInstitutionLifecycleKey &&
            other.sessionUserId == sessionUserId &&
            other.sessionInstanceId == sessionInstanceId &&
            other.institutionId == institutionId;
  }

  @override
  int get hashCode =>
      Object.hash(sessionUserId, sessionInstanceId, institutionId);
}

class PlatformInstitutionLifecycleOperation {
  const PlatformInstitutionLifecycleOperation({
    required this.institutionId,
    required this.institutionName,
    required this.sourceStatus,
    required this.action,
    required this.sessionUserId,
    required this.sessionInstanceId,
    required this.requestGeneration,
  });

  final String institutionId;
  final String institutionName;
  final PlatformInstitutionStatus sourceStatus;
  final PlatformInstitutionLifecycleAction action;
  final String sessionUserId;
  final int sessionInstanceId;
  final int requestGeneration;

  PlatformInstitutionStatus get targetStatus => action.targetStatus;

  PlatformInstitutionLifecycleOperation copyWithRequestGeneration(int value) {
    return PlatformInstitutionLifecycleOperation(
      institutionId: institutionId,
      institutionName: institutionName,
      sourceStatus: sourceStatus,
      action: action,
      sessionUserId: sessionUserId,
      sessionInstanceId: sessionInstanceId,
      requestGeneration: value,
    );
  }
}

enum PlatformInstitutionLifecycleStatus {
  idle,
  confirming,
  submitting,
  confirmed,
  reconciling,
  definiteFailure,
  unknownOutcome,
}

class PlatformInstitutionLifecycleState {
  const PlatformInstitutionLifecycleState._({
    required this.status,
    required this.operation,
    required this.result,
    required this.failure,
    required this.currentStatus,
    required this.message,
  });

  const PlatformInstitutionLifecycleState.idle()
    : this._(
        status: PlatformInstitutionLifecycleStatus.idle,
        operation: null,
        result: null,
        failure: null,
        currentStatus: null,
        message: null,
      );

  const PlatformInstitutionLifecycleState.confirming(
    PlatformInstitutionLifecycleOperation operation,
  ) : this._(
        status: PlatformInstitutionLifecycleStatus.confirming,
        operation: operation,
        result: null,
        failure: null,
        currentStatus: null,
        message: null,
      );

  const PlatformInstitutionLifecycleState.submitting(
    PlatformInstitutionLifecycleOperation operation,
  ) : this._(
        status: PlatformInstitutionLifecycleStatus.submitting,
        operation: operation,
        result: null,
        failure: null,
        currentStatus: null,
        message: null,
      );

  PlatformInstitutionLifecycleState.confirmed({
    required PlatformInstitutionLifecycleOperation operation,
    required PlatformInstitutionLifecycleResult result,
  }) : this._(
         status: PlatformInstitutionLifecycleStatus.confirmed,
         operation: operation,
         result: result,
         failure: null,
         currentStatus: result.status,
         message: null,
       );

  const PlatformInstitutionLifecycleState.reconciling(
    PlatformInstitutionLifecycleOperation operation,
  ) : this._(
        status: PlatformInstitutionLifecycleStatus.reconciling,
        operation: operation,
        result: null,
        failure: null,
        currentStatus: null,
        message: 'Checking current status...',
      );

  const PlatformInstitutionLifecycleState.definiteFailure({
    required PlatformInstitutionLifecycleOperation operation,
    required String message,
    ApiFailure? failure,
    PlatformInstitutionStatus? currentStatus,
  }) : this._(
         status: PlatformInstitutionLifecycleStatus.definiteFailure,
         operation: operation,
         result: null,
         failure: failure,
         currentStatus: currentStatus,
         message: message,
       );

  const PlatformInstitutionLifecycleState.unknownOutcome({
    required PlatformInstitutionLifecycleOperation operation,
    required String message,
    ApiFailure? failure,
    PlatformInstitutionStatus? currentStatus,
  }) : this._(
         status: PlatformInstitutionLifecycleStatus.unknownOutcome,
         operation: operation,
         result: null,
         failure: failure,
         currentStatus: currentStatus,
         message: message,
       );

  final PlatformInstitutionLifecycleStatus status;
  final PlatformInstitutionLifecycleOperation? operation;
  final PlatformInstitutionLifecycleResult? result;
  final ApiFailure? failure;
  final PlatformInstitutionStatus? currentStatus;
  final String? message;

  bool get isIdle => status == PlatformInstitutionLifecycleStatus.idle;

  bool get isBusy {
    return status == PlatformInstitutionLifecycleStatus.submitting ||
        status == PlatformInstitutionLifecycleStatus.reconciling;
  }

  bool get canOpenConfirmation => isIdle;

  bool get canConfirm {
    return status == PlatformInstitutionLifecycleStatus.confirming;
  }

  bool get canDismiss {
    return !isBusy && status != PlatformInstitutionLifecycleStatus.idle;
  }

  bool get canCheckStatus {
    return status == PlatformInstitutionLifecycleStatus.unknownOutcome &&
        currentStatus == null;
  }

  bool get hasConfirmedTargetEvidence {
    return status == PlatformInstitutionLifecycleStatus.confirmed &&
        result != null &&
        operation != null;
  }
}
