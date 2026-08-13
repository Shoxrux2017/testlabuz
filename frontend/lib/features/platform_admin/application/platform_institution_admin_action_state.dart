import '../../../core/network/api_failure.dart';
import '../domain/platform_institution_admin.dart';
import '../domain/platform_institution_admin_lifecycle.dart';
import '../domain/platform_institution_admin_update.dart';

class PlatformInstitutionAdminActionKey {
  const PlatformInstitutionAdminActionKey({
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
        other is PlatformInstitutionAdminActionKey &&
            other.sessionUserId == sessionUserId &&
            other.sessionInstanceId == sessionInstanceId &&
            other.institutionId == institutionId;
  }

  @override
  int get hashCode {
    return Object.hash(sessionUserId, sessionInstanceId, institutionId);
  }
}

enum PlatformInstitutionAdminActionKind { edit, lifecycle }

class PlatformInstitutionAdminActionSnapshot {
  const PlatformInstitutionAdminActionSnapshot({
    required this.institutionId,
    required this.admin,
    required this.sessionUserId,
    required this.sessionInstanceId,
    required this.requestGeneration,
    required this.kind,
    this.lifecycleAction,
    int? actionGeneration,
  }) : actionGeneration = actionGeneration ?? requestGeneration;

  final String institutionId;
  final PlatformInstitutionAdmin admin;
  final String sessionUserId;
  final int sessionInstanceId;
  final int actionGeneration;
  final int requestGeneration;
  final PlatformInstitutionAdminActionKind kind;
  final PlatformInstitutionAdminLifecycleAction? lifecycleAction;

  String get adminId => admin.id;

  String get loginName => admin.loginName;

  PlatformInstitutionAdminActionSnapshot copyWithRequestGeneration(int value) {
    return PlatformInstitutionAdminActionSnapshot(
      institutionId: institutionId,
      admin: admin,
      sessionUserId: sessionUserId,
      sessionInstanceId: sessionInstanceId,
      actionGeneration: actionGeneration,
      requestGeneration: value,
      kind: kind,
      lifecycleAction: lifecycleAction,
    );
  }
}

enum PlatformInstitutionAdminActionStatus {
  idle,
  editing,
  validationFailure,
  editSubmitting,
  lifecycleConfirming,
  lifecycleSubmitting,
  reconciling,
  success,
  definiteFailure,
  unknownOutcome,
  targetUnavailable,
}

enum PlatformInstitutionAdminActionCompletionKind {
  profileUpdated,
  lifecycleChanged,
  targetUnavailable,
}

class PlatformInstitutionAdminActionCompletion {
  const PlatformInstitutionAdminActionCompletion({
    required this.kind,
    required this.message,
    this.lifecycleAction,
  });

  final PlatformInstitutionAdminActionCompletionKind kind;
  final String message;
  final PlatformInstitutionAdminLifecycleAction? lifecycleAction;
}

class PlatformInstitutionAdminActionState {
  const PlatformInstitutionAdminActionState._({
    required this.status,
    required this.snapshot,
    required this.form,
    required this.fieldErrors,
    required this.formError,
    required this.failure,
    required this.message,
    required this.resultAdmin,
    required this.completion,
    required this.firstErrorField,
  });

  const PlatformInstitutionAdminActionState.idle()
    : this._(
        status: PlatformInstitutionAdminActionStatus.idle,
        snapshot: null,
        form: null,
        fieldErrors: const {},
        formError: null,
        failure: null,
        message: null,
        resultAdmin: null,
        completion: null,
        firstErrorField: null,
      );

  PlatformInstitutionAdminActionState.editing({
    required PlatformInstitutionAdminActionSnapshot snapshot,
    required PlatformInstitutionAdminEditFormValue form,
  }) : this._(
         status: PlatformInstitutionAdminActionStatus.editing,
         snapshot: snapshot,
         form: form,
         fieldErrors: const {},
         formError: null,
         failure: null,
         message: null,
         resultAdmin: null,
         completion: null,
         firstErrorField: null,
       );

  PlatformInstitutionAdminActionState.validationFailure({
    required PlatformInstitutionAdminActionSnapshot snapshot,
    required PlatformInstitutionAdminEditFormValue form,
    required Map<PlatformInstitutionAdminEditField, List<String>> fieldErrors,
    required PlatformInstitutionAdminEditField? firstErrorField,
    String? formError,
    ApiFailure? failure,
  }) : this._(
         status: PlatformInstitutionAdminActionStatus.validationFailure,
         snapshot: snapshot,
         form: form,
         fieldErrors: _freezeFieldErrors(fieldErrors),
         formError: formError,
         failure: failure,
         message: null,
         resultAdmin: null,
         completion: null,
         firstErrorField: firstErrorField,
       );

  PlatformInstitutionAdminActionState.editSubmitting({
    required PlatformInstitutionAdminActionSnapshot snapshot,
    required PlatformInstitutionAdminEditFormValue form,
  }) : this._(
         status: PlatformInstitutionAdminActionStatus.editSubmitting,
         snapshot: snapshot,
         form: form,
         fieldErrors: const {},
         formError: null,
         failure: null,
         message: null,
         resultAdmin: null,
         completion: null,
         firstErrorField: null,
       );

  const PlatformInstitutionAdminActionState.lifecycleConfirming({
    required PlatformInstitutionAdminActionSnapshot snapshot,
  }) : this._(
         status: PlatformInstitutionAdminActionStatus.lifecycleConfirming,
         snapshot: snapshot,
         form: null,
         fieldErrors: const {},
         formError: null,
         failure: null,
         message: null,
         resultAdmin: null,
         completion: null,
         firstErrorField: null,
       );

  const PlatformInstitutionAdminActionState.lifecycleSubmitting({
    required PlatformInstitutionAdminActionSnapshot snapshot,
  }) : this._(
         status: PlatformInstitutionAdminActionStatus.lifecycleSubmitting,
         snapshot: snapshot,
         form: null,
         fieldErrors: const {},
         formError: null,
         failure: null,
         message: null,
         resultAdmin: null,
         completion: null,
         firstErrorField: null,
       );

  PlatformInstitutionAdminActionState.reconciling({
    required PlatformInstitutionAdminActionSnapshot snapshot,
    required PlatformInstitutionAdminEditFormValue? form,
  }) : this._(
         status: PlatformInstitutionAdminActionStatus.reconciling,
         snapshot: snapshot,
         form: form,
         fieldErrors: const {},
         formError: null,
         failure: null,
         message: 'Checking the current server state...',
         resultAdmin: null,
         completion: null,
         firstErrorField: null,
       );

  PlatformInstitutionAdminActionState.success({
    required PlatformInstitutionAdminActionSnapshot snapshot,
    required PlatformInstitutionAdminEditFormValue? form,
    required PlatformInstitutionAdmin resultAdmin,
    required PlatformInstitutionAdminActionCompletion completion,
  }) : this._(
         status: PlatformInstitutionAdminActionStatus.success,
         snapshot: snapshot,
         form: form,
         fieldErrors: const {},
         formError: null,
         failure: null,
         message: completion.message,
         resultAdmin: resultAdmin,
         completion: completion,
         firstErrorField: null,
       );

  PlatformInstitutionAdminActionState.definiteFailure({
    required PlatformInstitutionAdminActionSnapshot snapshot,
    required PlatformInstitutionAdminEditFormValue? form,
    required String message,
    ApiFailure? failure,
  }) : this._(
         status: PlatformInstitutionAdminActionStatus.definiteFailure,
         snapshot: snapshot,
         form: form,
         fieldErrors: const {},
         formError: null,
         failure: failure,
         message: message,
         resultAdmin: null,
         completion: null,
         firstErrorField: null,
       );

  PlatformInstitutionAdminActionState.unknownOutcome({
    required PlatformInstitutionAdminActionSnapshot snapshot,
    required PlatformInstitutionAdminEditFormValue? form,
    required String message,
    ApiFailure? failure,
    PlatformInstitutionAdmin? currentAdmin,
  }) : this._(
         status: PlatformInstitutionAdminActionStatus.unknownOutcome,
         snapshot: snapshot,
         form: form,
         fieldErrors: const {},
         formError: null,
         failure: failure,
         message: message,
         resultAdmin: currentAdmin,
         completion: null,
         firstErrorField: null,
       );

  PlatformInstitutionAdminActionState.targetUnavailable({
    required PlatformInstitutionAdminActionSnapshot snapshot,
    required PlatformInstitutionAdminEditFormValue? form,
    required String message,
  }) : this._(
         status: PlatformInstitutionAdminActionStatus.targetUnavailable,
         snapshot: snapshot,
         form: form,
         fieldErrors: const {},
         formError: null,
         failure: null,
         message: message,
         resultAdmin: null,
         completion: PlatformInstitutionAdminActionCompletion(
           kind: PlatformInstitutionAdminActionCompletionKind.targetUnavailable,
           message: message,
         ),
         firstErrorField: null,
       );

  final PlatformInstitutionAdminActionStatus status;
  final PlatformInstitutionAdminActionSnapshot? snapshot;
  final PlatformInstitutionAdminEditFormValue? form;
  final Map<PlatformInstitutionAdminEditField, List<String>> fieldErrors;
  final String? formError;
  final ApiFailure? failure;
  final String? message;
  final PlatformInstitutionAdmin? resultAdmin;
  final PlatformInstitutionAdminActionCompletion? completion;
  final PlatformInstitutionAdminEditField? firstErrorField;

  bool get isIdle => status == PlatformInstitutionAdminActionStatus.idle;

  bool get isBusy {
    return status == PlatformInstitutionAdminActionStatus.editSubmitting ||
        status == PlatformInstitutionAdminActionStatus.lifecycleSubmitting ||
        status == PlatformInstitutionAdminActionStatus.reconciling;
  }

  bool get canStartAction => isIdle;

  bool get canSubmitEdit {
    return !isBusy &&
        snapshot?.kind == PlatformInstitutionAdminActionKind.edit &&
        (status == PlatformInstitutionAdminActionStatus.editing ||
            status == PlatformInstitutionAdminActionStatus.validationFailure ||
            status == PlatformInstitutionAdminActionStatus.definiteFailure);
  }

  bool get canConfirmLifecycle {
    return status == PlatformInstitutionAdminActionStatus.lifecycleConfirming;
  }

  bool get canDismiss {
    return !isBusy && !isIdle;
  }

  bool get isEditDialogState {
    return snapshot?.kind == PlatformInstitutionAdminActionKind.edit;
  }

  bool get isLifecycleDialogState {
    return snapshot?.kind == PlatformInstitutionAdminActionKind.lifecycle;
  }

  String? errorTextFor(PlatformInstitutionAdminEditField field) {
    final errors = fieldErrors[field];
    if (errors == null || errors.isEmpty) {
      return null;
    }

    return errors.first;
  }

  PlatformInstitutionAdminActionState withForm(
    PlatformInstitutionAdminEditFormValue form, {
    PlatformInstitutionAdminEditField? clearFieldError,
  }) {
    final currentSnapshot = snapshot;
    if (currentSnapshot == null) {
      return this;
    }

    final errors = <PlatformInstitutionAdminEditField, List<String>>{
      for (final entry in fieldErrors.entries) entry.key: entry.value,
    };
    if (clearFieldError != null) {
      errors.remove(clearFieldError);
    }

    return errors.isEmpty
        ? PlatformInstitutionAdminActionState.editing(
            snapshot: currentSnapshot,
            form: form,
          )
        : PlatformInstitutionAdminActionState.validationFailure(
            snapshot: currentSnapshot,
            form: form,
            fieldErrors: errors,
            firstErrorField: _firstFieldIn(errors),
            formError: formError,
            failure: failure,
          );
  }

  static Map<PlatformInstitutionAdminEditField, List<String>>
  _freezeFieldErrors(
    Map<PlatformInstitutionAdminEditField, List<String>> fieldErrors,
  ) {
    final frozen = <PlatformInstitutionAdminEditField, List<String>>{};

    for (final entry in fieldErrors.entries) {
      frozen[entry.key] = List<String>.unmodifiable(entry.value);
    }

    return Map<PlatformInstitutionAdminEditField, List<String>>.unmodifiable(
      frozen,
    );
  }

  static PlatformInstitutionAdminEditField? _firstFieldIn(
    Map<PlatformInstitutionAdminEditField, List<String>> fieldErrors,
  ) {
    for (final field in PlatformInstitutionAdminEditField.values) {
      if (fieldErrors.containsKey(field)) {
        return field;
      }
    }

    return null;
  }
}
