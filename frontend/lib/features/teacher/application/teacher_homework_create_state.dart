import '../../../core/network/api_failure.dart';
import '../domain/teacher_homework_form.dart';
import '../domain/teacher_topic.dart';

enum TeacherHomeworkCreateStatus {
  loading,
  initialLoadError,
  editing,
  localValidationFailure,
  serverValidationFailure,
  submitting,
  definiteFailure,
  topicNotEditable,
  unavailable,
  outcomeUnknown,
  confirmedSuccess,
}

class TeacherHomeworkCreateState {
  TeacherHomeworkCreateState._({
    required this.status,
    required this.topic,
    required this.form,
    required Set<String> rememberedSelectedIds,
    required Map<TeacherHomeworkFormField, String> fieldErrors,
    required this.formError,
    required this.firstErrorField,
    required this.initialLoadFailure,
    required this.confirmedHomeworkId,
  }) : rememberedSelectedIds = Set<String>.unmodifiable(rememberedSelectedIds),
       fieldErrors = Map<TeacherHomeworkFormField, String>.unmodifiable(
         fieldErrors,
       );

  factory TeacherHomeworkCreateState.loading() {
    return TeacherHomeworkCreateState._(
      status: TeacherHomeworkCreateStatus.loading,
      topic: null,
      form: TeacherHomeworkFormValue(),
      rememberedSelectedIds: const {},
      fieldErrors: const {},
      formError: null,
      firstErrorField: null,
      initialLoadFailure: null,
      confirmedHomeworkId: null,
    );
  }

  factory TeacherHomeworkCreateState.initialLoadError(ApiFailure failure) {
    return TeacherHomeworkCreateState._(
      status: TeacherHomeworkCreateStatus.initialLoadError,
      topic: null,
      form: TeacherHomeworkFormValue(),
      rememberedSelectedIds: const {},
      fieldErrors: const {},
      formError: null,
      firstErrorField: null,
      initialLoadFailure: failure,
      confirmedHomeworkId: null,
    );
  }

  factory TeacherHomeworkCreateState.editing({
    required TeacherTopic topic,
    TeacherHomeworkFormValue? form,
    Set<String> rememberedSelectedIds = const {},
    String? formError,
    TeacherHomeworkCreateStatus status = TeacherHomeworkCreateStatus.editing,
  }) {
    return TeacherHomeworkCreateState._(
      status: status,
      topic: topic,
      form: form ?? TeacherHomeworkFormValue(),
      rememberedSelectedIds: rememberedSelectedIds,
      fieldErrors: const {},
      formError: formError,
      firstErrorField: null,
      initialLoadFailure: null,
      confirmedHomeworkId: null,
    );
  }

  factory TeacherHomeworkCreateState.validation({
    required TeacherHomeworkCreateStatus status,
    required TeacherTopic topic,
    required TeacherHomeworkFormValue form,
    required Set<String> rememberedSelectedIds,
    required Map<TeacherHomeworkFormField, String> fieldErrors,
    required String? formError,
  }) {
    return TeacherHomeworkCreateState._(
      status: status,
      topic: topic,
      form: form,
      rememberedSelectedIds: rememberedSelectedIds,
      fieldErrors: fieldErrors,
      formError: formError,
      firstErrorField: _firstField(fieldErrors),
      initialLoadFailure: null,
      confirmedHomeworkId: null,
    );
  }

  factory TeacherHomeworkCreateState.submitting({
    required TeacherTopic topic,
    required TeacherHomeworkFormValue form,
    required Set<String> rememberedSelectedIds,
  }) {
    return TeacherHomeworkCreateState._(
      status: TeacherHomeworkCreateStatus.submitting,
      topic: topic,
      form: form,
      rememberedSelectedIds: rememberedSelectedIds,
      fieldErrors: const {},
      formError: null,
      firstErrorField: null,
      initialLoadFailure: null,
      confirmedHomeworkId: null,
    );
  }

  factory TeacherHomeworkCreateState.review({
    required TeacherHomeworkCreateStatus status,
    required TeacherTopic? topic,
    required TeacherHomeworkFormValue form,
    required Set<String> rememberedSelectedIds,
    required String formError,
  }) {
    return TeacherHomeworkCreateState._(
      status: status,
      topic: topic,
      form: form,
      rememberedSelectedIds: rememberedSelectedIds,
      fieldErrors: const {},
      formError: formError,
      firstErrorField: null,
      initialLoadFailure: null,
      confirmedHomeworkId: null,
    );
  }

  factory TeacherHomeworkCreateState.success({
    required TeacherTopic topic,
    required String homeworkId,
  }) {
    return TeacherHomeworkCreateState._(
      status: TeacherHomeworkCreateStatus.confirmedSuccess,
      topic: topic,
      form: TeacherHomeworkFormValue(),
      rememberedSelectedIds: const {},
      fieldErrors: const {},
      formError: null,
      firstErrorField: null,
      initialLoadFailure: null,
      confirmedHomeworkId: homeworkId,
    );
  }

  final TeacherHomeworkCreateStatus status;
  final TeacherTopic? topic;
  final TeacherHomeworkFormValue form;
  final Set<String> rememberedSelectedIds;
  final Map<TeacherHomeworkFormField, String> fieldErrors;
  final String? formError;
  final TeacherHomeworkFormField? firstErrorField;
  final ApiFailure? initialLoadFailure;
  final String? confirmedHomeworkId;

  bool get isBusy => status == TeacherHomeworkCreateStatus.submitting;
  bool get isReviewOnly =>
      status == TeacherHomeworkCreateStatus.topicNotEditable ||
      status == TeacherHomeworkCreateStatus.unavailable ||
      status == TeacherHomeworkCreateStatus.outcomeUnknown;
  bool get isRouteBlocking =>
      isBusy || status == TeacherHomeworkCreateStatus.outcomeUnknown;
  bool get canEdit =>
      topic != null &&
      !isReviewOnly &&
      !isBusy &&
      status != TeacherHomeworkCreateStatus.loading &&
      status != TeacherHomeworkCreateStatus.initialLoadError &&
      status != TeacherHomeworkCreateStatus.confirmedSuccess;
  bool get canSubmit => canEdit;
  bool get isDirty =>
      status != TeacherHomeworkCreateStatus.confirmedSuccess &&
      form != TeacherHomeworkFormValue();
  bool get blocksNavigation => isRouteBlocking || isDirty;

  String? errorFor(TeacherHomeworkFormField field) => fieldErrors[field];

  TeacherHomeworkCreateState withForm(
    TeacherHomeworkFormValue next, {
    required Set<TeacherHomeworkFormField> clearErrors,
    Set<String>? rememberedSelectedIds,
  }) {
    if (!canEdit || topic == null) {
      return this;
    }
    final errors = <TeacherHomeworkFormField, String>{...fieldErrors};
    for (final field in clearErrors) {
      errors.remove(field);
    }
    return TeacherHomeworkCreateState._(
      status: errors.isEmpty ? TeacherHomeworkCreateStatus.editing : status,
      topic: topic,
      form: next,
      rememberedSelectedIds:
          rememberedSelectedIds ?? this.rememberedSelectedIds,
      fieldErrors: errors,
      formError: errors.isEmpty ? null : formError,
      firstErrorField: _firstField(errors),
      initialLoadFailure: null,
      confirmedHomeworkId: null,
    );
  }

  TeacherHomeworkCreateState withTopic(TeacherTopic currentTopic) {
    return TeacherHomeworkCreateState._(
      status: status,
      topic: currentTopic,
      form: form,
      rememberedSelectedIds: rememberedSelectedIds,
      fieldErrors: fieldErrors,
      formError: formError,
      firstErrorField: firstErrorField,
      initialLoadFailure: initialLoadFailure,
      confirmedHomeworkId: confirmedHomeworkId,
    );
  }
}

TeacherHomeworkFormField? _firstField(
  Map<TeacherHomeworkFormField, Object?> errors,
) {
  for (final field in TeacherHomeworkFormField.values) {
    if (errors.containsKey(field)) {
      return field;
    }
  }
  return null;
}
