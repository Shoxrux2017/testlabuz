import '../domain/teacher_topic_mutation.dart';

enum TeacherTopicCreateStatus {
  editing,
  localValidationFailure,
  submitting,
  serverValidationFailure,
  definiteFailure,
  reconcilingUnknown,
  unknown,
  confirmedSuccess,
}

class TeacherTopicCreateState {
  const TeacherTopicCreateState._({
    required this.status,
    required this.form,
    required this.fieldErrors,
    required this.formError,
    required this.firstErrorField,
    required this.confirmedTopicId,
    required this.submittedGroupId,
  });

  const TeacherTopicCreateState.editing({
    TeacherTopicFormValue form = const TeacherTopicFormValue(),
    String? formError,
  }) : this._(
         status: TeacherTopicCreateStatus.editing,
         form: form,
         fieldErrors: const {},
         formError: formError,
         firstErrorField: null,
         confirmedTopicId: null,
         submittedGroupId: null,
       );

  TeacherTopicCreateState.validation({
    required TeacherTopicCreateStatus status,
    required TeacherTopicFormValue form,
    required Map<TeacherTopicFormField, String> fieldErrors,
    required String? formError,
  }) : this._(
         status: status,
         form: form,
         fieldErrors: Map.unmodifiable(fieldErrors),
         formError: formError,
         firstErrorField: _firstField(fieldErrors),
         confirmedTopicId: null,
         submittedGroupId: null,
       );

  const TeacherTopicCreateState.submitting({
    required TeacherTopicFormValue form,
    required String groupId,
    bool reconciling = false,
  }) : this._(
         status: reconciling
             ? TeacherTopicCreateStatus.reconcilingUnknown
             : TeacherTopicCreateStatus.submitting,
         form: form,
         fieldErrors: const {},
         formError: null,
         firstErrorField: null,
         confirmedTopicId: null,
         submittedGroupId: groupId,
       );

  const TeacherTopicCreateState.failure({
    required TeacherTopicFormValue form,
    required String formError,
  }) : this._(
         status: TeacherTopicCreateStatus.definiteFailure,
         form: form,
         fieldErrors: const {},
         formError: formError,
         firstErrorField: null,
         confirmedTopicId: null,
         submittedGroupId: null,
       );

  const TeacherTopicCreateState.unknown({
    required TeacherTopicFormValue form,
    required String groupId,
  }) : this._(
         status: TeacherTopicCreateStatus.unknown,
         form: form,
         fieldErrors: const {},
         formError: null,
         firstErrorField: null,
         confirmedTopicId: null,
         submittedGroupId: groupId,
       );

  const TeacherTopicCreateState.success(String topicId)
    : this._(
        status: TeacherTopicCreateStatus.confirmedSuccess,
        form: const TeacherTopicFormValue(),
        fieldErrors: const {},
        formError: null,
        firstErrorField: null,
        confirmedTopicId: topicId,
        submittedGroupId: null,
      );

  final TeacherTopicCreateStatus status;
  final TeacherTopicFormValue form;
  final Map<TeacherTopicFormField, String> fieldErrors;
  final String? formError;
  final TeacherTopicFormField? firstErrorField;
  final String? confirmedTopicId;
  final String? submittedGroupId;

  bool get isUnknown => status == TeacherTopicCreateStatus.unknown;
  bool get isRouteBlocking =>
      status == TeacherTopicCreateStatus.submitting ||
      status == TeacherTopicCreateStatus.reconcilingUnknown ||
      status == TeacherTopicCreateStatus.unknown;
  bool get canEdit => !isRouteBlocking && confirmedTopicId == null;
  bool get canSubmit => canEdit;

  String? errorFor(TeacherTopicFormField field) => fieldErrors[field];

  TeacherTopicCreateState withForm(
    TeacherTopicFormValue next, {
    TeacherTopicFormField? clearError,
  }) {
    if (!canEdit) {
      return this;
    }
    final errors = <TeacherTopicFormField, String>{...fieldErrors};
    if (clearError != null) {
      errors.remove(clearError);
    }

    return TeacherTopicCreateState._(
      status: errors.isEmpty ? TeacherTopicCreateStatus.editing : status,
      form: next,
      fieldErrors: Map.unmodifiable(errors),
      formError: errors.isEmpty ? null : formError,
      firstErrorField: _firstField(errors),
      confirmedTopicId: null,
      submittedGroupId: null,
    );
  }
}

TeacherTopicFormField? _firstField(Map<TeacherTopicFormField, Object?> errors) {
  for (final field in TeacherTopicFormField.values) {
    if (errors.containsKey(field)) {
      return field;
    }
  }

  return null;
}
