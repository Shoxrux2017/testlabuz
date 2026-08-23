import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_mutation.dart';

enum TeacherTopicEditStatus {
  loading,
  editing,
  localValidationFailure,
  serverValidationFailure,
  submitting,
  reconciling,
  definiteFailure,
  topicNotEditable,
  unconfirmedCurrentState,
  outcomeUnknown,
  unavailable,
  confirmedSuccess,
}

class TeacherTopicEditState {
  const TeacherTopicEditState._({
    required this.status,
    required this.topic,
    required this.form,
    required this.initial,
    required this.attemptedDraft,
    required this.fieldErrors,
    required this.formError,
    required this.firstErrorField,
    required this.pendingRequest,
  });

  const TeacherTopicEditState.loading()
    : this._(
        status: TeacherTopicEditStatus.loading,
        topic: null,
        form: null,
        initial: null,
        attemptedDraft: null,
        fieldErrors: const {},
        formError: null,
        firstErrorField: null,
        pendingRequest: null,
      );

  const TeacherTopicEditState.editing({
    required TeacherTopic topic,
    required TeacherTopicFormValue form,
    required TeacherTopicEditSnapshot initial,
    String? formError,
    TeacherTopicEditStatus status = TeacherTopicEditStatus.editing,
    Map<TeacherTopicFormField, String> fieldErrors = const {},
  }) : this._(
         status: status,
         topic: topic,
         form: form,
         initial: initial,
         attemptedDraft: null,
         fieldErrors: fieldErrors,
         formError: formError,
         firstErrorField: null,
         pendingRequest: null,
       );

  TeacherTopicEditState.validation({
    required TeacherTopicEditStatus status,
    required TeacherTopic topic,
    required TeacherTopicFormValue form,
    required TeacherTopicEditSnapshot initial,
    required Map<TeacherTopicFormField, String> fieldErrors,
    required String? formError,
  }) : this._(
         status: status,
         topic: topic,
         form: form,
         initial: initial,
         attemptedDraft: null,
         fieldErrors: Map.unmodifiable(fieldErrors),
         formError: formError,
         firstErrorField: _firstField(fieldErrors),
         pendingRequest: null,
       );

  const TeacherTopicEditState.busy({
    required TeacherTopicEditStatus status,
    required TeacherTopic topic,
    required TeacherTopicFormValue form,
    required TeacherTopicEditSnapshot initial,
    required TeacherTopicEditRequest request,
  }) : this._(
         status: status,
         topic: topic,
         form: form,
         initial: initial,
         attemptedDraft: form,
         fieldErrors: const {},
         formError: null,
         firstErrorField: null,
         pendingRequest: request,
       );

  const TeacherTopicEditState.review({
    required TeacherTopicEditStatus status,
    required TeacherTopic? topic,
    required TeacherTopicFormValue attemptedDraft,
    required TeacherTopicEditSnapshot initial,
    required TeacherTopicEditRequest request,
    required String formError,
  }) : this._(
         status: status,
         topic: topic,
         form: attemptedDraft,
         initial: initial,
         attemptedDraft: attemptedDraft,
         fieldErrors: const {},
         formError: formError,
         firstErrorField: null,
         pendingRequest: request,
       );

  const TeacherTopicEditState.success({required TeacherTopic topic})
    : this._(
        status: TeacherTopicEditStatus.confirmedSuccess,
        topic: topic,
        form: null,
        initial: null,
        attemptedDraft: null,
        fieldErrors: const {},
        formError: null,
        firstErrorField: null,
        pendingRequest: null,
      );

  const TeacherTopicEditState.unavailable({
    String message = 'This Topic is unavailable.',
  }) : this._(
         status: TeacherTopicEditStatus.unavailable,
         topic: null,
         form: null,
         initial: null,
         attemptedDraft: null,
         fieldErrors: const {},
         formError: message,
         firstErrorField: null,
         pendingRequest: null,
       );

  final TeacherTopicEditStatus status;
  final TeacherTopic? topic;
  final TeacherTopicFormValue? form;
  final TeacherTopicEditSnapshot? initial;
  final TeacherTopicFormValue? attemptedDraft;
  final Map<TeacherTopicFormField, String> fieldErrors;
  final String? formError;
  final TeacherTopicFormField? firstErrorField;
  final TeacherTopicEditRequest? pendingRequest;

  bool get isBusy =>
      status == TeacherTopicEditStatus.submitting ||
      status == TeacherTopicEditStatus.reconciling;
  bool get isReviewOnly =>
      status == TeacherTopicEditStatus.topicNotEditable ||
      status == TeacherTopicEditStatus.unconfirmedCurrentState ||
      status == TeacherTopicEditStatus.outcomeUnknown ||
      status == TeacherTopicEditStatus.unavailable;
  bool get canEdit => !isBusy && !isReviewOnly && form != null;
  bool get canSave => canEdit;

  bool get isDirty {
    final current = form;
    final snapshot = initial;
    if (current == null ||
        snapshot == null ||
        status == TeacherTopicEditStatus.confirmedSuccess) {
      return false;
    }

    return current.normalizedTitle != snapshot.title ||
        current.normalizedDescription != snapshot.description ||
        current.normalizedSubject != snapshot.subject ||
        current.normalizedStudentInstructions != snapshot.studentInstructions ||
        current.lessonAt != snapshot.lessonAt;
  }

  bool get blocksNavigation => isBusy || isDirty;
  String? errorFor(TeacherTopicFormField field) => fieldErrors[field];

  TeacherTopicEditState withForm(
    TeacherTopicFormValue next, {
    required TeacherTopicFormField clearError,
  }) {
    if (!canEdit || topic == null || initial == null) {
      return this;
    }
    final errors = <TeacherTopicFormField, String>{...fieldErrors}
      ..remove(clearError);

    return TeacherTopicEditState._(
      status: errors.isEmpty ? TeacherTopicEditStatus.editing : status,
      topic: topic,
      form: next,
      initial: initial,
      attemptedDraft: null,
      fieldErrors: Map.unmodifiable(errors),
      formError: errors.isEmpty ? null : formError,
      firstErrorField: _firstField(errors),
      pendingRequest: null,
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
