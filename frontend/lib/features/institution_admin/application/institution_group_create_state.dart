import '../domain/institution_group_create.dart';

enum InstitutionGroupCreateStatus {
  editing,
  localValidationFailure,
  submitting,
  serverValidationFailure,
  definiteFailure,
  reconcilingUnknown,
  unknown,
  confirmedSuccess,
}

class InstitutionGroupCreateState {
  const InstitutionGroupCreateState._({
    required this.status,
    required this.form,
    required this.fieldErrors,
    required this.formError,
    required this.firstErrorField,
    required this.confirmedGroupId,
  });

  const InstitutionGroupCreateState.editing({
    InstitutionGroupCreateFormValue form =
        const InstitutionGroupCreateFormValue(),
  }) : this._(
         status: InstitutionGroupCreateStatus.editing,
         form: form,
         fieldErrors: const {},
         formError: null,
         firstErrorField: null,
         confirmedGroupId: null,
       );

  InstitutionGroupCreateState.localValidationFailure({
    required InstitutionGroupCreateFormValue form,
    required Map<InstitutionGroupCreateField, String> fieldErrors,
  }) : this._(
         status: InstitutionGroupCreateStatus.localValidationFailure,
         form: form,
         fieldErrors: Map.unmodifiable(fieldErrors),
         formError: 'Review the highlighted fields.',
         firstErrorField: _firstField(fieldErrors),
         confirmedGroupId: null,
       );

  const InstitutionGroupCreateState.submitting({
    required InstitutionGroupCreateFormValue form,
  }) : this._(
         status: InstitutionGroupCreateStatus.submitting,
         form: form,
         fieldErrors: const {},
         formError: null,
         firstErrorField: null,
         confirmedGroupId: null,
       );

  InstitutionGroupCreateState.serverValidationFailure({
    required InstitutionGroupCreateFormValue form,
    required Map<InstitutionGroupCreateField, String> fieldErrors,
    required String? formError,
  }) : this._(
         status: InstitutionGroupCreateStatus.serverValidationFailure,
         form: form,
         fieldErrors: Map.unmodifiable(fieldErrors),
         formError: formError,
         firstErrorField: _firstField(fieldErrors),
         confirmedGroupId: null,
       );

  const InstitutionGroupCreateState.definiteFailure({
    required InstitutionGroupCreateFormValue form,
    required String formError,
  }) : this._(
         status: InstitutionGroupCreateStatus.definiteFailure,
         form: form,
         fieldErrors: const {},
         formError: formError,
         firstErrorField: null,
         confirmedGroupId: null,
       );

  const InstitutionGroupCreateState.reconcilingUnknown({
    required InstitutionGroupCreateFormValue form,
  }) : this._(
         status: InstitutionGroupCreateStatus.reconcilingUnknown,
         form: form,
         fieldErrors: const {},
         formError: null,
         firstErrorField: null,
         confirmedGroupId: null,
       );

  const InstitutionGroupCreateState.unknown({
    required InstitutionGroupCreateFormValue form,
  }) : this._(
         status: InstitutionGroupCreateStatus.unknown,
         form: form,
         fieldErrors: const {},
         formError: null,
         firstErrorField: null,
         confirmedGroupId: null,
       );

  const InstitutionGroupCreateState.confirmedSuccess({required String groupId})
    : this._(
        status: InstitutionGroupCreateStatus.confirmedSuccess,
        form: const InstitutionGroupCreateFormValue(),
        fieldErrors: const {},
        formError: null,
        firstErrorField: null,
        confirmedGroupId: groupId,
      );

  final InstitutionGroupCreateStatus status;
  final InstitutionGroupCreateFormValue form;
  final Map<InstitutionGroupCreateField, String> fieldErrors;
  final String? formError;
  final InstitutionGroupCreateField? firstErrorField;
  final String? confirmedGroupId;

  bool get isUnknown => status == InstitutionGroupCreateStatus.unknown;

  bool get isRouteBlocking =>
      status == InstitutionGroupCreateStatus.submitting ||
      status == InstitutionGroupCreateStatus.reconcilingUnknown ||
      status == InstitutionGroupCreateStatus.unknown;

  bool get canEdit => !isRouteBlocking && confirmedGroupId == null;
  bool get canSubmit => canEdit;

  String? errorTextFor(InstitutionGroupCreateField field) {
    return fieldErrors[field];
  }

  InstitutionGroupCreateState withForm(
    InstitutionGroupCreateFormValue form, {
    InstitutionGroupCreateField? clearFieldError,
  }) {
    if (!canEdit) {
      return this;
    }

    final errors = <InstitutionGroupCreateField, String>{...fieldErrors};
    if (clearFieldError != null) {
      errors.remove(clearFieldError);
    }

    return InstitutionGroupCreateState._(
      status: errors.isEmpty ? InstitutionGroupCreateStatus.editing : status,
      form: form,
      fieldErrors: Map.unmodifiable(errors),
      formError: errors.isEmpty ? null : formError,
      firstErrorField: _firstField(errors),
      confirmedGroupId: null,
    );
  }
}

InstitutionGroupCreateField? _firstField(
  Map<InstitutionGroupCreateField, Object?> errors,
) {
  for (final field in InstitutionGroupCreateField.values) {
    if (errors.containsKey(field)) {
      return field;
    }
  }

  return null;
}
