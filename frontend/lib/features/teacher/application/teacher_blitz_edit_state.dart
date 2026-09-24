import '../../../core/network/api_failure.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_form.dart';
import '../domain/teacher_blitz_mutation.dart';

enum TeacherBlitzEditStatus {
  loading,
  initialLoadError,
  editing,
  localValidationFailure,
  serverValidationFailure,
  submitting,
  reconciling,
  definiteFailure,
  lifecycleUnavailable,
  officialInconsistent,
  conflictReview,
  unconfirmedCurrentState,
  outcomeReview,
  unavailable,
  confirmedSuccess,
}

class TeacherBlitzEditState {
  TeacherBlitzEditState._({
    required this.status,
    required this.blitz,
    required this.form,
    required this.initial,
    required this.officialAssignmentLocked,
    required Map<TeacherBlitzFormField, String> fieldErrors,
    required this.formError,
    required this.pendingRequest,
    required this.reconciliationConflictCode,
    required this.initialLoadFailure,
  }) : fieldErrors = Map<TeacherBlitzFormField, String>.unmodifiable(
         fieldErrors,
       );

  factory TeacherBlitzEditState.loading() {
    return TeacherBlitzEditState._(
      status: TeacherBlitzEditStatus.loading,
      blitz: null,
      form: null,
      initial: null,
      officialAssignmentLocked: false,
      fieldErrors: const {},
      formError: null,
      pendingRequest: null,
      reconciliationConflictCode: null,
      initialLoadFailure: null,
    );
  }

  factory TeacherBlitzEditState.initialLoadError(ApiFailure failure) {
    return TeacherBlitzEditState._(
      status: TeacherBlitzEditStatus.initialLoadError,
      blitz: null,
      form: null,
      initial: null,
      officialAssignmentLocked: false,
      fieldErrors: const {},
      formError: null,
      pendingRequest: null,
      reconciliationConflictCode: null,
      initialLoadFailure: failure,
    );
  }

  /// Starts an editable form from an authoritative Draft/Scheduled Blitz.
  factory TeacherBlitzEditState.fromBlitz(
    TeacherBlitz blitz, {
    required bool officialAssignmentLocked,
  }) {
    return TeacherBlitzEditState.editing(
      blitz: blitz,
      form: TeacherBlitzFormValue.fromBlitz(blitz),
      initial: TeacherBlitzEditSnapshot.fromBlitz(blitz),
      officialAssignmentLocked: officialAssignmentLocked,
    );
  }

  factory TeacherBlitzEditState.editing({
    required TeacherBlitz blitz,
    required TeacherBlitzFormValue form,
    required TeacherBlitzEditSnapshot initial,
    required bool officialAssignmentLocked,
    TeacherBlitzEditStatus status = TeacherBlitzEditStatus.editing,
    Map<TeacherBlitzFormField, String> fieldErrors = const {},
    String? formError,
  }) {
    return TeacherBlitzEditState._(
      status: status,
      blitz: blitz,
      form: form,
      initial: initial,
      officialAssignmentLocked: officialAssignmentLocked,
      fieldErrors: fieldErrors,
      formError: formError,
      pendingRequest: null,
      reconciliationConflictCode: null,
      initialLoadFailure: null,
    );
  }

  factory TeacherBlitzEditState.busy({
    required TeacherBlitzEditStatus status,
    required TeacherBlitz blitz,
    required TeacherBlitzFormValue form,
    required TeacherBlitzEditSnapshot initial,
    required bool officialAssignmentLocked,
    required TeacherBlitzEditRequest request,
    String? conflictCode,
  }) {
    return TeacherBlitzEditState._(
      status: status,
      blitz: blitz,
      form: form,
      initial: initial,
      officialAssignmentLocked: officialAssignmentLocked,
      fieldErrors: const {},
      formError: null,
      pendingRequest: request,
      reconciliationConflictCode: conflictCode,
      initialLoadFailure: null,
    );
  }

  factory TeacherBlitzEditState.review({
    required TeacherBlitzEditStatus status,
    required TeacherBlitz? blitz,
    required TeacherBlitzFormValue? attemptedDraft,
    required TeacherBlitzEditSnapshot? initial,
    required bool officialAssignmentLocked,
    required String formError,
    TeacherBlitzEditRequest? request,
    String? conflictCode,
  }) {
    return TeacherBlitzEditState._(
      status: status,
      blitz: blitz,
      form: attemptedDraft,
      initial: initial,
      officialAssignmentLocked: officialAssignmentLocked,
      fieldErrors: const {},
      formError: formError,
      pendingRequest: request,
      reconciliationConflictCode: conflictCode,
      initialLoadFailure: null,
    );
  }

  factory TeacherBlitzEditState.success(TeacherBlitz blitz) {
    return TeacherBlitzEditState._(
      status: TeacherBlitzEditStatus.confirmedSuccess,
      blitz: blitz,
      form: TeacherBlitzFormValue.fromBlitz(blitz),
      initial: TeacherBlitzEditSnapshot.fromBlitz(blitz),
      officialAssignmentLocked: false,
      fieldErrors: const {},
      formError: null,
      pendingRequest: null,
      reconciliationConflictCode: null,
      initialLoadFailure: null,
    );
  }

  final TeacherBlitzEditStatus status;

  /// The latest authoritative Blitz known to this form.
  final TeacherBlitz? blitz;
  final TeacherBlitzFormValue? form;
  final TeacherBlitzEditSnapshot? initial;

  /// True only when the confirmed result pair designates this Blitz.
  final bool officialAssignmentLocked;
  final Map<TeacherBlitzFormField, String> fieldErrors;
  final String? formError;
  final TeacherBlitzEditRequest? pendingRequest;
  final String? reconciliationConflictCode;
  final ApiFailure? initialLoadFailure;

  TeacherBlitzFormField? get firstErrorField {
    for (final field in TeacherBlitzFormField.values) {
      if (fieldErrors.containsKey(field)) {
        return field;
      }
    }
    return null;
  }

  bool get isBusy =>
      status == TeacherBlitzEditStatus.submitting ||
      status == TeacherBlitzEditStatus.reconciling;

  bool get isReviewOnly => switch (status) {
    TeacherBlitzEditStatus.lifecycleUnavailable ||
    TeacherBlitzEditStatus.officialInconsistent ||
    TeacherBlitzEditStatus.conflictReview ||
    TeacherBlitzEditStatus.unconfirmedCurrentState ||
    TeacherBlitzEditStatus.outcomeReview ||
    TeacherBlitzEditStatus.unavailable => true,
    _ => false,
  };

  bool get canEdit =>
      !isBusy &&
      !isReviewOnly &&
      blitz != null &&
      form != null &&
      initial != null &&
      status != TeacherBlitzEditStatus.loading &&
      status != TeacherBlitzEditStatus.initialLoadError &&
      status != TeacherBlitzEditStatus.confirmedSuccess;

  bool get isDirty {
    final currentForm = form;
    final snapshot = initial;
    if (status == TeacherBlitzEditStatus.confirmedSuccess ||
        currentForm == null ||
        snapshot == null) {
      return false;
    }
    try {
      return !TeacherBlitzEditRequest.fromForm(
        form: currentForm,
        initial: snapshot,
      ).isEmpty;
    } on ArgumentError {
      // An invalid draft always differs from the valid authoritative Blitz.
      return true;
    }
  }

  /// Busy work and an unresolved outcome both forbid leaving silently.
  bool get isRouteBlocking =>
      isBusy || status == TeacherBlitzEditStatus.outcomeReview;

  bool get blocksNavigation => isRouteBlocking || isDirty;

  String? errorFor(TeacherBlitzFormField field) => fieldErrors[field];

  TeacherBlitzEditState withForm(
    TeacherBlitzFormValue next, {
    required Set<TeacherBlitzFormField> clearErrors,
  }) {
    final currentBlitz = blitz;
    final snapshot = initial;
    if (!canEdit || currentBlitz == null || snapshot == null) {
      return this;
    }
    final errors = <TeacherBlitzFormField, String>{...fieldErrors};
    errors.removeWhere((field, _) => clearErrors.contains(field));
    return TeacherBlitzEditState.editing(
      blitz: currentBlitz,
      form: next,
      initial: snapshot,
      officialAssignmentLocked: officialAssignmentLocked,
      status: errors.isEmpty ? TeacherBlitzEditStatus.editing : status,
      fieldErrors: errors,
      formError: errors.isEmpty ? null : formError,
    );
  }

  /// Keeps an unsaved draft while adopting a newer authoritative context.
  ///
  /// A confirmed official designation forces whole-group assignment, so a
  /// selected-student draft falls back to the group before it can be saved.
  TeacherBlitzEditState withAuthoritativeContext({
    required TeacherBlitz blitz,
    required bool officialAssignmentLocked,
  }) {
    var nextForm = form;
    var nextErrors = fieldErrors;
    if (officialAssignmentLocked &&
        nextForm != null &&
        nextForm.assignmentMode != TeacherBlitzAssignmentMode.group) {
      nextForm = nextForm.copyWith(
        assignmentMode: TeacherBlitzAssignmentMode.group,
        selectedStudentIds: const {},
      );
      nextErrors = {...fieldErrors}
        ..remove(TeacherBlitzFormField.assignmentMode)
        ..remove(TeacherBlitzFormField.studentIds);
    }
    return TeacherBlitzEditState._(
      status: status,
      blitz: blitz,
      form: nextForm,
      initial: initial,
      officialAssignmentLocked: officialAssignmentLocked,
      fieldErrors: nextErrors,
      formError: formError,
      pendingRequest: pendingRequest,
      reconciliationConflictCode: reconciliationConflictCode,
      initialLoadFailure: initialLoadFailure,
    );
  }
}
