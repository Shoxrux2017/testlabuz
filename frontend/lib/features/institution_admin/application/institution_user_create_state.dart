import '../domain/institution_user_create.dart';

enum InstitutionUserCreateStatus {
  editing,
  localValidationFailure,
  submitting,
  serverValidationFailure,
  definiteFailure,
  reconcilingUnknown,
  unknownPossibleMatch,
  unknownInconclusive,
  confirmedSuccess,
}

class InstitutionUserCreateState {
  const InstitutionUserCreateState._({
    required this.status,
    required this.form,
    required this.fieldErrors,
    required this.formError,
    required this.firstErrorField,
    required this.confirmedUserId,
    required this.passwordWipeGeneration,
  });

  const InstitutionUserCreateState.editing({
    InstitutionUserCreateFormValue form =
        const InstitutionUserCreateFormValue(),
    int passwordWipeGeneration = 0,
  }) : this._(
         status: InstitutionUserCreateStatus.editing,
         form: form,
         fieldErrors: const {},
         formError: null,
         firstErrorField: null,
         confirmedUserId: null,
         passwordWipeGeneration: passwordWipeGeneration,
       );

  InstitutionUserCreateState.localValidationFailure({
    required InstitutionUserCreateFormValue form,
    required Map<InstitutionUserCreateField, String> fieldErrors,
    required int passwordWipeGeneration,
  }) : this._(
         status: InstitutionUserCreateStatus.localValidationFailure,
         form: form,
         fieldErrors: Map<InstitutionUserCreateField, String>.unmodifiable(
           fieldErrors,
         ),
         formError: 'Review the highlighted fields.',
         firstErrorField: _firstField(fieldErrors),
         confirmedUserId: null,
         passwordWipeGeneration: passwordWipeGeneration,
       );

  InstitutionUserCreateState.submitting({
    required InstitutionUserCreateFormValue form,
    required int passwordWipeGeneration,
  }) : this._(
         status: InstitutionUserCreateStatus.submitting,
         form: form,
         fieldErrors: const {},
         formError: null,
         firstErrorField: null,
         confirmedUserId: null,
         passwordWipeGeneration: passwordWipeGeneration,
       );

  InstitutionUserCreateState.serverValidationFailure({
    required InstitutionUserCreateFormValue form,
    required Map<InstitutionUserCreateField, String> fieldErrors,
    required String? formError,
    required int passwordWipeGeneration,
  }) : this._(
         status: InstitutionUserCreateStatus.serverValidationFailure,
         form: form,
         fieldErrors: Map<InstitutionUserCreateField, String>.unmodifiable(
           fieldErrors,
         ),
         formError: formError,
         firstErrorField: _firstField(fieldErrors),
         confirmedUserId: null,
         passwordWipeGeneration: passwordWipeGeneration,
       );

  InstitutionUserCreateState.definiteFailure({
    required InstitutionUserCreateFormValue form,
    required String formError,
    required int passwordWipeGeneration,
  }) : this._(
         status: InstitutionUserCreateStatus.definiteFailure,
         form: form,
         fieldErrors: const {},
         formError: formError,
         firstErrorField: null,
         confirmedUserId: null,
         passwordWipeGeneration: passwordWipeGeneration,
       );

  InstitutionUserCreateState.reconcilingUnknown({
    required InstitutionUserCreateFormValue form,
    required int passwordWipeGeneration,
  }) : this._(
         status: InstitutionUserCreateStatus.reconcilingUnknown,
         form: form,
         fieldErrors: const {},
         formError: null,
         firstErrorField: null,
         confirmedUserId: null,
         passwordWipeGeneration: passwordWipeGeneration,
       );

  InstitutionUserCreateState.unknown({
    required InstitutionUserCreateFormValue form,
    required bool possibleMatch,
    required int passwordWipeGeneration,
  }) : this._(
         status: possibleMatch
             ? InstitutionUserCreateStatus.unknownPossibleMatch
             : InstitutionUserCreateStatus.unknownInconclusive,
         form: form,
         fieldErrors: const {},
         formError: null,
         firstErrorField: null,
         confirmedUserId: null,
         passwordWipeGeneration: passwordWipeGeneration,
       );

  InstitutionUserCreateState.confirmedSuccess({
    required String userId,
    required int passwordWipeGeneration,
  }) : this._(
         status: InstitutionUserCreateStatus.confirmedSuccess,
         form: const InstitutionUserCreateFormValue(),
         fieldErrors: const {},
         formError: null,
         firstErrorField: null,
         confirmedUserId: userId,
         passwordWipeGeneration: passwordWipeGeneration,
       );

  final InstitutionUserCreateStatus status;
  final InstitutionUserCreateFormValue form;
  final Map<InstitutionUserCreateField, String> fieldErrors;
  final String? formError;
  final InstitutionUserCreateField? firstErrorField;
  final String? confirmedUserId;
  final int passwordWipeGeneration;

  bool get isBusy =>
      status == InstitutionUserCreateStatus.submitting ||
      status == InstitutionUserCreateStatus.reconcilingUnknown;

  bool get isUnknown =>
      status == InstitutionUserCreateStatus.unknownPossibleMatch ||
      status == InstitutionUserCreateStatus.unknownInconclusive;

  bool get canEdit => !isBusy && !isUnknown && confirmedUserId == null;

  bool get canSubmit => canEdit;

  String? errorTextFor(InstitutionUserCreateField field) {
    return fieldErrors[field];
  }

  InstitutionUserCreateState withForm(
    InstitutionUserCreateFormValue form, {
    InstitutionUserCreateField? clearFieldError,
  }) {
    if (!canEdit) {
      return this;
    }

    final errors = <InstitutionUserCreateField, String>{...fieldErrors};
    if (clearFieldError != null) {
      errors.remove(clearFieldError);
    }

    return InstitutionUserCreateState._(
      status: errors.isEmpty ? InstitutionUserCreateStatus.editing : status,
      form: form,
      fieldErrors: Map<InstitutionUserCreateField, String>.unmodifiable(errors),
      formError: errors.isEmpty ? null : formError,
      firstErrorField: _firstField(errors),
      confirmedUserId: null,
      passwordWipeGeneration: passwordWipeGeneration,
    );
  }
}

InstitutionUserCreateField? _firstField(
  Map<InstitutionUserCreateField, Object?> errors,
) {
  for (final field in InstitutionUserCreateField.values) {
    if (errors.containsKey(field)) {
      return field;
    }
  }

  return null;
}
