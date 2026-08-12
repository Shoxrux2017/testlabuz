import '../../../core/network/api_failure.dart';
import '../domain/platform_institution_create.dart';

class PlatformInstitutionCreateKey {
  const PlatformInstitutionCreateKey({
    required this.sessionUserId,
    required this.sessionInstanceId,
  });

  final String sessionUserId;
  final int sessionInstanceId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlatformInstitutionCreateKey &&
            other.sessionUserId == sessionUserId &&
            other.sessionInstanceId == sessionInstanceId;
  }

  @override
  int get hashCode => Object.hash(sessionUserId, sessionInstanceId);
}

enum PlatformInstitutionCreateStatus {
  editing,
  submitting,
  validationFailure,
  failure,
  outcomeUnknown,
  success,
}

class PlatformInstitutionCreateState {
  const PlatformInstitutionCreateState._({
    required this.status,
    required this.form,
    required this.fieldErrors,
    required this.formError,
    required this.result,
    required this.failure,
    required this.firstErrorField,
  });

  const PlatformInstitutionCreateState.editing({
    PlatformInstitutionCreateFormValue form =
        const PlatformInstitutionCreateFormValue(),
  }) : this._(
         status: PlatformInstitutionCreateStatus.editing,
         form: form,
         fieldErrors: const {},
         formError: null,
         result: null,
         failure: null,
         firstErrorField: null,
       );

  PlatformInstitutionCreateState.submitting({
    required PlatformInstitutionCreateFormValue form,
  }) : this._(
         status: PlatformInstitutionCreateStatus.submitting,
         form: form,
         fieldErrors: const {},
         formError: null,
         result: null,
         failure: null,
         firstErrorField: null,
       );

  PlatformInstitutionCreateState.validationFailure({
    required PlatformInstitutionCreateFormValue form,
    required Map<PlatformInstitutionCreateField, List<String>> fieldErrors,
    required PlatformInstitutionCreateField? firstErrorField,
    String? formError,
    ApiFailure? failure,
  }) : this._(
         status: PlatformInstitutionCreateStatus.validationFailure,
         form: form,
         fieldErrors: _freezeFieldErrors(fieldErrors),
         formError: formError,
         result: null,
         failure: failure,
         firstErrorField: firstErrorField,
       );

  PlatformInstitutionCreateState.failure({
    required PlatformInstitutionCreateFormValue form,
    required String formError,
    required ApiFailure failure,
  }) : this._(
         status: PlatformInstitutionCreateStatus.failure,
         form: form,
         fieldErrors: const {},
         formError: formError,
         result: null,
         failure: failure,
         firstErrorField: null,
       );

  PlatformInstitutionCreateState.outcomeUnknown({
    required PlatformInstitutionCreateFormValue form,
  }) : this._(
         status: PlatformInstitutionCreateStatus.outcomeUnknown,
         form: form,
         fieldErrors: const {},
         formError: 'Submission outcome unknown.',
         result: null,
         failure: null,
         firstErrorField: null,
       );

  PlatformInstitutionCreateState.success({
    required PlatformInstitutionCreateFormValue form,
    required PlatformInstitutionCreateResult result,
  }) : this._(
         status: PlatformInstitutionCreateStatus.success,
         form: form,
         fieldErrors: const {},
         formError: null,
         result: result,
         failure: null,
         firstErrorField: null,
       );

  final PlatformInstitutionCreateStatus status;
  final PlatformInstitutionCreateFormValue form;
  final Map<PlatformInstitutionCreateField, List<String>> fieldErrors;
  final String? formError;
  final PlatformInstitutionCreateResult? result;
  final ApiFailure? failure;
  final PlatformInstitutionCreateField? firstErrorField;

  bool get isSubmitting => status == PlatformInstitutionCreateStatus.submitting;

  bool get isOutcomeUnknown {
    return status == PlatformInstitutionCreateStatus.outcomeUnknown;
  }

  bool get canSubmit {
    return !isSubmitting &&
        status != PlatformInstitutionCreateStatus.success &&
        status != PlatformInstitutionCreateStatus.outcomeUnknown;
  }

  String? errorTextFor(PlatformInstitutionCreateField field) {
    final errors = fieldErrors[field];
    if (errors == null || errors.isEmpty) {
      return null;
    }

    return errors.first;
  }

  PlatformInstitutionCreateState withForm(
    PlatformInstitutionCreateFormValue form, {
    PlatformInstitutionCreateField? clearFieldError,
  }) {
    final errors = <PlatformInstitutionCreateField, List<String>>{
      for (final entry in fieldErrors.entries) entry.key: entry.value,
    };

    if (clearFieldError != null) {
      errors.remove(clearFieldError);
    }

    return PlatformInstitutionCreateState._(
      status: errors.isEmpty
          ? PlatformInstitutionCreateStatus.editing
          : PlatformInstitutionCreateStatus.validationFailure,
      form: form,
      fieldErrors: _freezeFieldErrors(errors),
      formError: errors.isEmpty ? null : formError,
      result: null,
      failure: errors.isEmpty ? null : failure,
      firstErrorField: _firstFieldIn(errors),
    );
  }

  static Map<PlatformInstitutionCreateField, List<String>> _freezeFieldErrors(
    Map<PlatformInstitutionCreateField, List<String>> fieldErrors,
  ) {
    final frozen = <PlatformInstitutionCreateField, List<String>>{};

    for (final entry in fieldErrors.entries) {
      frozen[entry.key] = List<String>.unmodifiable(entry.value);
    }

    return Map<PlatformInstitutionCreateField, List<String>>.unmodifiable(
      frozen,
    );
  }

  static PlatformInstitutionCreateField? _firstFieldIn(
    Map<PlatformInstitutionCreateField, List<String>> fieldErrors,
  ) {
    for (final field in PlatformInstitutionCreateField.values) {
      if (fieldErrors.containsKey(field)) {
        return field;
      }
    }

    return null;
  }
}
