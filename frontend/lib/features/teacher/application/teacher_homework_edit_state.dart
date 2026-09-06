import '../../../core/network/api_failure.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_homework_form.dart';
import '../domain/teacher_homework_mutation.dart';
import '../domain/teacher_topic.dart';

enum TeacherHomeworkEditStatus {
  loading,
  initialLoadError,
  editing,
  localValidationFailure,
  serverValidationFailure,
  submitting,
  reconciling,
  definiteFailure,
  taskClosed,
  taskArchived,
  topicNotEditable,
  businessConflict,
  officialTaskRequiresGroupAssignment,
  unconfirmedCurrentState,
  outcomeUnknown,
  unavailable,
  confirmedSuccess,
}

class TeacherHomeworkEditState {
  TeacherHomeworkEditState._({
    required this.status,
    required this.topic,
    required this.homework,
    required this.form,
    required this.initial,
    required this.institutionTimezone,
    required this.attemptedDraft,
    required Set<String> rememberedSelectedIds,
    required Map<TeacherHomeworkFormField, String> fieldErrors,
    required this.formError,
    required this.firstErrorField,
    required this.pendingRequest,
    required this.reconciliationConflictCode,
    required this.initialLoadFailure,
    required this.confirmedHomework,
  }) : rememberedSelectedIds = Set<String>.unmodifiable(rememberedSelectedIds),
       fieldErrors = Map<TeacherHomeworkFormField, String>.unmodifiable(
         fieldErrors,
       );

  factory TeacherHomeworkEditState.loading() {
    return TeacherHomeworkEditState._(
      status: TeacherHomeworkEditStatus.loading,
      topic: null,
      homework: null,
      form: null,
      initial: null,
      institutionTimezone: null,
      attemptedDraft: null,
      rememberedSelectedIds: const {},
      fieldErrors: const {},
      formError: null,
      firstErrorField: null,
      pendingRequest: null,
      reconciliationConflictCode: null,
      initialLoadFailure: null,
      confirmedHomework: null,
    );
  }

  factory TeacherHomeworkEditState.initialLoadError(ApiFailure failure) {
    return TeacherHomeworkEditState._(
      status: TeacherHomeworkEditStatus.initialLoadError,
      topic: null,
      homework: null,
      form: null,
      initial: null,
      institutionTimezone: null,
      attemptedDraft: null,
      rememberedSelectedIds: const {},
      fieldErrors: const {},
      formError: null,
      firstErrorField: null,
      pendingRequest: null,
      reconciliationConflictCode: null,
      initialLoadFailure: failure,
      confirmedHomework: null,
    );
  }

  factory TeacherHomeworkEditState.editing({
    required TeacherTopic topic,
    required TeacherHomework homework,
    required TeacherHomeworkFormValue form,
    required TeacherHomeworkEditSnapshot initial,
    required String institutionTimezone,
    required Set<String> rememberedSelectedIds,
    String? formError,
    TeacherHomeworkEditStatus status = TeacherHomeworkEditStatus.editing,
  }) {
    return TeacherHomeworkEditState._(
      status: status,
      topic: topic,
      homework: homework,
      form: form,
      initial: initial,
      institutionTimezone: institutionTimezone,
      attemptedDraft: null,
      rememberedSelectedIds: rememberedSelectedIds,
      fieldErrors: const {},
      formError: formError,
      firstErrorField: null,
      pendingRequest: null,
      reconciliationConflictCode: null,
      initialLoadFailure: null,
      confirmedHomework: null,
    );
  }

  factory TeacherHomeworkEditState.validation({
    required TeacherHomeworkEditStatus status,
    required TeacherTopic topic,
    required TeacherHomework homework,
    required TeacherHomeworkFormValue form,
    required TeacherHomeworkEditSnapshot initial,
    required String institutionTimezone,
    required Set<String> rememberedSelectedIds,
    required Map<TeacherHomeworkFormField, String> fieldErrors,
    required String? formError,
  }) {
    return TeacherHomeworkEditState._(
      status: status,
      topic: topic,
      homework: homework,
      form: form,
      initial: initial,
      institutionTimezone: institutionTimezone,
      attemptedDraft: null,
      rememberedSelectedIds: rememberedSelectedIds,
      fieldErrors: fieldErrors,
      formError: formError,
      firstErrorField: _firstField(fieldErrors),
      pendingRequest: null,
      reconciliationConflictCode: null,
      initialLoadFailure: null,
      confirmedHomework: null,
    );
  }

  factory TeacherHomeworkEditState.busy({
    required TeacherHomeworkEditStatus status,
    required TeacherTopic topic,
    required TeacherHomework homework,
    required TeacherHomeworkFormValue form,
    required TeacherHomeworkEditSnapshot initial,
    required String institutionTimezone,
    required Set<String> rememberedSelectedIds,
    required TeacherHomeworkEditRequest request,
    String? conflictCode,
  }) {
    return TeacherHomeworkEditState._(
      status: status,
      topic: topic,
      homework: homework,
      form: form,
      initial: initial,
      institutionTimezone: institutionTimezone,
      attemptedDraft: form,
      rememberedSelectedIds: rememberedSelectedIds,
      fieldErrors: const {},
      formError: null,
      firstErrorField: null,
      pendingRequest: request,
      reconciliationConflictCode: conflictCode,
      initialLoadFailure: null,
      confirmedHomework: null,
    );
  }

  factory TeacherHomeworkEditState.review({
    required TeacherHomeworkEditStatus status,
    required TeacherTopic? topic,
    required TeacherHomework? homework,
    required TeacherHomeworkFormValue? attemptedDraft,
    required TeacherHomeworkEditSnapshot? initial,
    required String? institutionTimezone,
    required Set<String> rememberedSelectedIds,
    required TeacherHomeworkEditRequest? request,
    required String formError,
    String? conflictCode,
  }) {
    return TeacherHomeworkEditState._(
      status: status,
      topic: topic,
      homework: homework,
      form: attemptedDraft,
      initial: initial,
      institutionTimezone: institutionTimezone,
      attemptedDraft: attemptedDraft,
      rememberedSelectedIds: rememberedSelectedIds,
      fieldErrors: const {},
      formError: formError,
      firstErrorField: null,
      pendingRequest: request,
      reconciliationConflictCode: conflictCode,
      initialLoadFailure: null,
      confirmedHomework: null,
    );
  }

  factory TeacherHomeworkEditState.success({
    required TeacherTopic topic,
    required TeacherHomework homework,
    required TeacherHomeworkFormValue form,
    required TeacherHomeworkEditSnapshot initial,
    required String institutionTimezone,
  }) {
    return TeacherHomeworkEditState._(
      status: TeacherHomeworkEditStatus.confirmedSuccess,
      topic: topic,
      homework: homework,
      form: form,
      initial: initial,
      institutionTimezone: institutionTimezone,
      attemptedDraft: null,
      rememberedSelectedIds: form.selectedStudentIds,
      fieldErrors: const {},
      formError: null,
      firstErrorField: null,
      pendingRequest: null,
      reconciliationConflictCode: null,
      initialLoadFailure: null,
      confirmedHomework: homework,
    );
  }

  final TeacherHomeworkEditStatus status;
  final TeacherTopic? topic;
  final TeacherHomework? homework;
  final TeacherHomeworkFormValue? form;
  final TeacherHomeworkEditSnapshot? initial;
  final String? institutionTimezone;
  final TeacherHomeworkFormValue? attemptedDraft;
  final Set<String> rememberedSelectedIds;
  final Map<TeacherHomeworkFormField, String> fieldErrors;
  final String? formError;
  final TeacherHomeworkFormField? firstErrorField;
  final TeacherHomeworkEditRequest? pendingRequest;
  final String? reconciliationConflictCode;
  final ApiFailure? initialLoadFailure;
  final TeacherHomework? confirmedHomework;

  bool get isBusy =>
      status == TeacherHomeworkEditStatus.submitting ||
      status == TeacherHomeworkEditStatus.reconciling;
  bool get isReviewOnly => switch (status) {
    TeacherHomeworkEditStatus.taskClosed ||
    TeacherHomeworkEditStatus.taskArchived ||
    TeacherHomeworkEditStatus.topicNotEditable ||
    TeacherHomeworkEditStatus.businessConflict ||
    TeacherHomeworkEditStatus.officialTaskRequiresGroupAssignment ||
    TeacherHomeworkEditStatus.unconfirmedCurrentState ||
    TeacherHomeworkEditStatus.outcomeUnknown ||
    TeacherHomeworkEditStatus.unavailable => true,
    _ => false,
  };
  bool get canEdit =>
      !isBusy &&
      !isReviewOnly &&
      form != null &&
      topic != null &&
      homework != null &&
      initial != null &&
      institutionTimezone != null &&
      status != TeacherHomeworkEditStatus.confirmedSuccess;

  bool get isDirty {
    final currentForm = form;
    final snapshot = initial;
    final timezone = institutionTimezone;
    if (status == TeacherHomeworkEditStatus.confirmedSuccess ||
        currentForm == null ||
        snapshot == null ||
        timezone == null) {
      return false;
    }
    try {
      return !TeacherHomeworkEditRequest.fromForm(
        form: currentForm,
        initial: snapshot,
        institutionTimezone: timezone,
      ).isEmpty;
    } catch (_) {
      return true;
    }
  }

  bool get canSave {
    final currentForm = form;
    final timezone = institutionTimezone;
    return canEdit &&
        currentForm != null &&
        timezone != null &&
        currentForm.validate(institutionTimezone: timezone).isEmpty &&
        isDirty;
  }

  bool get blocksNavigation =>
      isBusy || status == TeacherHomeworkEditStatus.outcomeUnknown || isDirty;

  String? errorFor(TeacherHomeworkFormField field) => fieldErrors[field];

  TeacherHomeworkEditState withForm(
    TeacherHomeworkFormValue next, {
    required Set<TeacherHomeworkFormField> clearErrors,
    Set<String>? rememberedSelectedIds,
  }) {
    if (!canEdit ||
        topic == null ||
        homework == null ||
        initial == null ||
        institutionTimezone == null) {
      return this;
    }
    final errors = <TeacherHomeworkFormField, String>{...fieldErrors};
    for (final field in clearErrors) {
      errors.remove(field);
    }
    return TeacherHomeworkEditState._(
      status: errors.isEmpty ? TeacherHomeworkEditStatus.editing : status,
      topic: topic,
      homework: homework,
      form: next,
      initial: initial,
      institutionTimezone: institutionTimezone,
      attemptedDraft: null,
      rememberedSelectedIds:
          rememberedSelectedIds ?? this.rememberedSelectedIds,
      fieldErrors: errors,
      formError: errors.isEmpty ? null : formError,
      firstErrorField: _firstField(errors),
      pendingRequest: null,
      reconciliationConflictCode: null,
      initialLoadFailure: null,
      confirmedHomework: null,
    );
  }

  TeacherHomeworkEditState withTopic(TeacherTopic currentTopic) {
    return TeacherHomeworkEditState._(
      status: status,
      topic: currentTopic,
      homework: homework,
      form: form,
      initial: initial,
      institutionTimezone: institutionTimezone,
      attemptedDraft: attemptedDraft,
      rememberedSelectedIds: rememberedSelectedIds,
      fieldErrors: fieldErrors,
      formError: formError,
      firstErrorField: firstErrorField,
      pendingRequest: pendingRequest,
      reconciliationConflictCode: reconciliationConflictCode,
      initialLoadFailure: initialLoadFailure,
      confirmedHomework: confirmedHomework,
    );
  }

  TeacherHomeworkEditState withAuthoritativeContext({
    required TeacherTopic topic,
    required TeacherHomework homework,
  }) {
    return TeacherHomeworkEditState._(
      status: status,
      topic: topic,
      homework: homework,
      form: form,
      initial: initial,
      institutionTimezone: institutionTimezone,
      attemptedDraft: attemptedDraft,
      rememberedSelectedIds: rememberedSelectedIds,
      fieldErrors: fieldErrors,
      formError: formError,
      firstErrorField: firstErrorField,
      pendingRequest: pendingRequest,
      reconciliationConflictCode: reconciliationConflictCode,
      initialLoadFailure: initialLoadFailure,
      confirmedHomework: confirmedHomework,
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
