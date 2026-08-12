import '../../../core/network/api_failure.dart';
import '../domain/platform_institution_admin_create.dart';

class PlatformInstitutionAdminCreateKey {
  const PlatformInstitutionAdminCreateKey({
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
        other is PlatformInstitutionAdminCreateKey &&
            other.sessionUserId == sessionUserId &&
            other.sessionInstanceId == sessionInstanceId &&
            other.institutionId == institutionId;
  }

  @override
  int get hashCode {
    return Object.hash(sessionUserId, sessionInstanceId, institutionId);
  }
}

enum PlatformInstitutionAdminCreateStatus {
  editing,
  submitting,
  validationFailure,
  failure,
  outcomeUnknown,
  success,
}

class PlatformInstitutionAdminCreateState {
  const PlatformInstitutionAdminCreateState._({
    required this.status,
    required this.form,
    required this.fieldErrors,
    required this.formError,
    required this.result,
    required this.failure,
    required this.firstErrorField,
    required this.passwordWipeGeneration,
  });

  const PlatformInstitutionAdminCreateState.editing({
    PlatformInstitutionAdminCreateFormValue form =
        const PlatformInstitutionAdminCreateFormValue(),
    int passwordWipeGeneration = 0,
  }) : this._(
         status: PlatformInstitutionAdminCreateStatus.editing,
         form: form,
         fieldErrors: const {},
         formError: null,
         result: null,
         failure: null,
         firstErrorField: null,
         passwordWipeGeneration: passwordWipeGeneration,
       );

  PlatformInstitutionAdminCreateState.submitting({
    required PlatformInstitutionAdminCreateFormValue form,
    required int passwordWipeGeneration,
  }) : this._(
         status: PlatformInstitutionAdminCreateStatus.submitting,
         form: form,
         fieldErrors: const {},
         formError: null,
         result: null,
         failure: null,
         firstErrorField: null,
         passwordWipeGeneration: passwordWipeGeneration,
       );

  PlatformInstitutionAdminCreateState.validationFailure({
    required PlatformInstitutionAdminCreateFormValue form,
    required Map<PlatformInstitutionAdminCreateField, List<String>> fieldErrors,
    required PlatformInstitutionAdminCreateField? firstErrorField,
    required int passwordWipeGeneration,
    String? formError,
    ApiFailure? failure,
  }) : this._(
         status: PlatformInstitutionAdminCreateStatus.validationFailure,
         form: form,
         fieldErrors: _freezeFieldErrors(fieldErrors),
         formError: formError,
         result: null,
         failure: failure,
         firstErrorField: firstErrorField,
         passwordWipeGeneration: passwordWipeGeneration,
       );

  PlatformInstitutionAdminCreateState.failure({
    required PlatformInstitutionAdminCreateFormValue form,
    required String formError,
    required ApiFailure failure,
    required int passwordWipeGeneration,
  }) : this._(
         status: PlatformInstitutionAdminCreateStatus.failure,
         form: form,
         fieldErrors: const {},
         formError: formError,
         result: null,
         failure: failure,
         firstErrorField: null,
         passwordWipeGeneration: passwordWipeGeneration,
       );

  PlatformInstitutionAdminCreateState.outcomeUnknown({
    required PlatformInstitutionAdminCreateFormValue form,
    required int passwordWipeGeneration,
  }) : this._(
         status: PlatformInstitutionAdminCreateStatus.outcomeUnknown,
         form: form,
         fieldErrors: const {},
         formError:
             'Creation outcome is unknown. Refresh administrators before creating another account.',
         result: null,
         failure: null,
         firstErrorField: null,
         passwordWipeGeneration: passwordWipeGeneration,
       );

  PlatformInstitutionAdminCreateState.success({
    required PlatformInstitutionAdminCreateFormValue form,
    required PlatformInstitutionAdminCreateResult result,
    required int passwordWipeGeneration,
  }) : this._(
         status: PlatformInstitutionAdminCreateStatus.success,
         form: form,
         fieldErrors: const {},
         formError: null,
         result: result,
         failure: null,
         firstErrorField: null,
         passwordWipeGeneration: passwordWipeGeneration,
       );

  final PlatformInstitutionAdminCreateStatus status;
  final PlatformInstitutionAdminCreateFormValue form;
  final Map<PlatformInstitutionAdminCreateField, List<String>> fieldErrors;
  final String? formError;
  final PlatformInstitutionAdminCreateResult? result;
  final ApiFailure? failure;
  final PlatformInstitutionAdminCreateField? firstErrorField;
  final int passwordWipeGeneration;

  bool get isSubmitting {
    return status == PlatformInstitutionAdminCreateStatus.submitting;
  }

  bool get isOutcomeUnknown {
    return status == PlatformInstitutionAdminCreateStatus.outcomeUnknown;
  }

  bool get canSubmit {
    return !isSubmitting &&
        status != PlatformInstitutionAdminCreateStatus.success &&
        status != PlatformInstitutionAdminCreateStatus.outcomeUnknown;
  }

  String? errorTextFor(PlatformInstitutionAdminCreateField field) {
    final errors = fieldErrors[field];
    if (errors == null || errors.isEmpty) {
      return null;
    }

    return errors.first;
  }

  PlatformInstitutionAdminCreateState withForm(
    PlatformInstitutionAdminCreateFormValue form, {
    PlatformInstitutionAdminCreateField? clearFieldError,
  }) {
    final errors = <PlatformInstitutionAdminCreateField, List<String>>{
      for (final entry in fieldErrors.entries) entry.key: entry.value,
    };

    if (clearFieldError != null) {
      errors.remove(clearFieldError);
    }

    return PlatformInstitutionAdminCreateState._(
      status: errors.isEmpty
          ? PlatformInstitutionAdminCreateStatus.editing
          : PlatformInstitutionAdminCreateStatus.validationFailure,
      form: form,
      fieldErrors: _freezeFieldErrors(errors),
      formError: errors.isEmpty ? null : formError,
      result: null,
      failure: errors.isEmpty ? null : failure,
      firstErrorField: _firstFieldIn(errors),
      passwordWipeGeneration: passwordWipeGeneration,
    );
  }

  static Map<PlatformInstitutionAdminCreateField, List<String>>
  _freezeFieldErrors(
    Map<PlatformInstitutionAdminCreateField, List<String>> fieldErrors,
  ) {
    final frozen = <PlatformInstitutionAdminCreateField, List<String>>{};

    for (final entry in fieldErrors.entries) {
      frozen[entry.key] = List<String>.unmodifiable(entry.value);
    }

    return Map<PlatformInstitutionAdminCreateField, List<String>>.unmodifiable(
      frozen,
    );
  }

  static PlatformInstitutionAdminCreateField? _firstFieldIn(
    Map<PlatformInstitutionAdminCreateField, List<String>> fieldErrors,
  ) {
    for (final field in PlatformInstitutionAdminCreateField.values) {
      if (fieldErrors.containsKey(field)) {
        return field;
      }
    }

    return null;
  }
}
