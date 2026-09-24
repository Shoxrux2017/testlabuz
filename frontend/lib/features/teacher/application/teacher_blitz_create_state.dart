import '../../../core/network/api_failure.dart';
import '../domain/teacher_blitz_form.dart';
import '../domain/teacher_topic.dart';

enum TeacherBlitzCreateStatus {
  loading,
  initialLoadError,
  editing,
  localValidationFailure,
  serverValidationFailure,
  submitting,
  definiteFailure,
  topicNotEditable,
  unavailable,
  outcomeReview,
  confirmedSuccess,
}

class TeacherBlitzCreateState {
  TeacherBlitzCreateState._({
    required this.status,
    required this.topic,
    required this.form,
    required Map<TeacherBlitzFormField, String> fieldErrors,
    required this.formError,
    required this.initialLoadFailure,
    required this.confirmedBlitzId,
  }) : fieldErrors = Map<TeacherBlitzFormField, String>.unmodifiable(
         fieldErrors,
       );

  factory TeacherBlitzCreateState.loading() {
    return TeacherBlitzCreateState._(
      status: TeacherBlitzCreateStatus.loading,
      topic: null,
      form: TeacherBlitzFormValue(),
      fieldErrors: const {},
      formError: null,
      initialLoadFailure: null,
      confirmedBlitzId: null,
    );
  }

  factory TeacherBlitzCreateState.initialLoadError(ApiFailure failure) {
    return TeacherBlitzCreateState._(
      status: TeacherBlitzCreateStatus.initialLoadError,
      topic: null,
      form: TeacherBlitzFormValue(),
      fieldErrors: const {},
      formError: null,
      initialLoadFailure: failure,
      confirmedBlitzId: null,
    );
  }

  factory TeacherBlitzCreateState.editing({
    required TeacherTopic topic,
    TeacherBlitzFormValue? form,
    TeacherBlitzCreateStatus status = TeacherBlitzCreateStatus.editing,
    Map<TeacherBlitzFormField, String> fieldErrors = const {},
    String? formError,
  }) {
    return TeacherBlitzCreateState._(
      status: status,
      topic: topic,
      form: form ?? TeacherBlitzFormValue(),
      fieldErrors: fieldErrors,
      formError: formError,
      initialLoadFailure: null,
      confirmedBlitzId: null,
    );
  }

  factory TeacherBlitzCreateState.review({
    required TeacherBlitzCreateStatus status,
    required TeacherTopic? topic,
    required TeacherBlitzFormValue form,
    required String formError,
  }) {
    return TeacherBlitzCreateState._(
      status: status,
      topic: topic,
      form: form,
      fieldErrors: const {},
      formError: formError,
      initialLoadFailure: null,
      confirmedBlitzId: null,
    );
  }

  factory TeacherBlitzCreateState.success({
    required TeacherTopic topic,
    required String blitzId,
  }) {
    return TeacherBlitzCreateState._(
      status: TeacherBlitzCreateStatus.confirmedSuccess,
      topic: topic,
      form: TeacherBlitzFormValue(),
      fieldErrors: const {},
      formError: null,
      initialLoadFailure: null,
      confirmedBlitzId: blitzId,
    );
  }

  final TeacherBlitzCreateStatus status;
  final TeacherTopic? topic;
  final TeacherBlitzFormValue form;
  final Map<TeacherBlitzFormField, String> fieldErrors;
  final String? formError;
  final ApiFailure? initialLoadFailure;
  final String? confirmedBlitzId;

  TeacherBlitzFormField? get firstErrorField {
    for (final field in TeacherBlitzFormField.values) {
      if (fieldErrors.containsKey(field)) {
        return field;
      }
    }
    return null;
  }

  bool get isBusy => status == TeacherBlitzCreateStatus.submitting;

  bool get isReviewOnly =>
      status == TeacherBlitzCreateStatus.topicNotEditable ||
      status == TeacherBlitzCreateStatus.unavailable ||
      status == TeacherBlitzCreateStatus.outcomeReview;

  bool get canEdit =>
      topic != null &&
      !isReviewOnly &&
      !isBusy &&
      status != TeacherBlitzCreateStatus.loading &&
      status != TeacherBlitzCreateStatus.initialLoadError &&
      status != TeacherBlitzCreateStatus.confirmedSuccess;

  bool get canSubmit => canEdit;

  bool get isDirty =>
      status != TeacherBlitzCreateStatus.confirmedSuccess &&
      form != TeacherBlitzFormValue();

  /// Busy work and an uncertain create both forbid leaving silently.
  bool get isRouteBlocking =>
      isBusy || status == TeacherBlitzCreateStatus.outcomeReview;

  bool get blocksNavigation => isRouteBlocking || isDirty;

  String? errorFor(TeacherBlitzFormField field) => fieldErrors[field];

  TeacherBlitzCreateState withForm(
    TeacherBlitzFormValue next, {
    required Set<TeacherBlitzFormField> clearErrors,
  }) {
    final currentTopic = topic;
    if (!canEdit || currentTopic == null) {
      return this;
    }
    final errors = <TeacherBlitzFormField, String>{...fieldErrors};
    errors.removeWhere((field, _) => clearErrors.contains(field));
    return TeacherBlitzCreateState.editing(
      topic: currentTopic,
      form: next,
      status: errors.isEmpty ? TeacherBlitzCreateStatus.editing : status,
      fieldErrors: errors,
      formError: errors.isEmpty ? null : formError,
    );
  }

  TeacherBlitzCreateState withTopic(TeacherTopic currentTopic) {
    return TeacherBlitzCreateState._(
      status: status,
      topic: currentTopic,
      form: form,
      fieldErrors: fieldErrors,
      formError: formError,
      initialLoadFailure: initialLoadFailure,
      confirmedBlitzId: confirmedBlitzId,
    );
  }
}
