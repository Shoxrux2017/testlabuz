import '../../../core/network/api_failure.dart';
import '../domain/platform_institution_detail.dart';
import '../domain/platform_institution_edit.dart';

class PlatformInstitutionEditKey {
  const PlatformInstitutionEditKey({
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
        other is PlatformInstitutionEditKey &&
            other.sessionUserId == sessionUserId &&
            other.sessionInstanceId == sessionInstanceId &&
            other.institutionId == institutionId;
  }

  @override
  int get hashCode =>
      Object.hash(sessionUserId, sessionInstanceId, institutionId);
}

enum PlatformInstitutionEditStatus {
  initial,
  loading,
  ready,
  submitting,
  validationFailure,
  failure,
  outcomeUnknown,
  notFound,
  loadError,
  accessDenied,
  success,
}

class PlatformInstitutionEditState {
  const PlatformInstitutionEditState._({
    required this.status,
    required this.detail,
    required this.form,
    required this.initialSnapshot,
    required this.fieldErrors,
    required this.formError,
    required this.failure,
    required this.result,
    required this.firstErrorField,
    required this.isRetryInFlight,
  });

  const PlatformInstitutionEditState.initial()
    : this._(
        status: PlatformInstitutionEditStatus.initial,
        detail: null,
        form: null,
        initialSnapshot: null,
        fieldErrors: const {},
        formError: null,
        failure: null,
        result: null,
        firstErrorField: null,
        isRetryInFlight: false,
      );

  const PlatformInstitutionEditState.loading()
    : this._(
        status: PlatformInstitutionEditStatus.loading,
        detail: null,
        form: null,
        initialSnapshot: null,
        fieldErrors: const {},
        formError: null,
        failure: null,
        result: null,
        firstErrorField: null,
        isRetryInFlight: false,
      );

  PlatformInstitutionEditState.ready({
    required PlatformInstitutionDetail detail,
    required PlatformInstitutionEditFormValue form,
    required PlatformInstitutionEditSnapshot initialSnapshot,
    String? formError,
  }) : this._(
         status: PlatformInstitutionEditStatus.ready,
         detail: detail,
         form: form,
         initialSnapshot: initialSnapshot,
         fieldErrors: const {},
         formError: formError,
         failure: null,
         result: null,
         firstErrorField: null,
         isRetryInFlight: false,
       );

  PlatformInstitutionEditState.submitting({
    required PlatformInstitutionDetail detail,
    required PlatformInstitutionEditFormValue form,
    required PlatformInstitutionEditSnapshot initialSnapshot,
  }) : this._(
         status: PlatformInstitutionEditStatus.submitting,
         detail: detail,
         form: form,
         initialSnapshot: initialSnapshot,
         fieldErrors: const {},
         formError: null,
         failure: null,
         result: null,
         firstErrorField: null,
         isRetryInFlight: false,
       );

  PlatformInstitutionEditState.validationFailure({
    required PlatformInstitutionDetail detail,
    required PlatformInstitutionEditFormValue form,
    required PlatformInstitutionEditSnapshot initialSnapshot,
    required Map<PlatformInstitutionEditField, List<String>> fieldErrors,
    required PlatformInstitutionEditField? firstErrorField,
    String? formError,
    ApiFailure? failure,
  }) : this._(
         status: PlatformInstitutionEditStatus.validationFailure,
         detail: detail,
         form: form,
         initialSnapshot: initialSnapshot,
         fieldErrors: _freezeFieldErrors(fieldErrors),
         formError: formError,
         failure: failure,
         result: null,
         firstErrorField: firstErrorField,
         isRetryInFlight: false,
       );

  PlatformInstitutionEditState.failure({
    required PlatformInstitutionDetail detail,
    required PlatformInstitutionEditFormValue form,
    required PlatformInstitutionEditSnapshot initialSnapshot,
    required String formError,
    required ApiFailure failure,
  }) : this._(
         status: PlatformInstitutionEditStatus.failure,
         detail: detail,
         form: form,
         initialSnapshot: initialSnapshot,
         fieldErrors: const {},
         formError: formError,
         failure: failure,
         result: null,
         firstErrorField: null,
         isRetryInFlight: false,
       );

  PlatformInstitutionEditState.outcomeUnknown({
    required PlatformInstitutionDetail detail,
    required PlatformInstitutionEditFormValue form,
    required PlatformInstitutionEditSnapshot initialSnapshot,
  }) : this._(
         status: PlatformInstitutionEditStatus.outcomeUnknown,
         detail: detail,
         form: form,
         initialSnapshot: initialSnapshot,
         fieldErrors: const {},
         formError: 'Update outcome unknown.',
         failure: null,
         result: null,
         firstErrorField: null,
         isRetryInFlight: false,
       );

  const PlatformInstitutionEditState.notFound()
    : this._(
        status: PlatformInstitutionEditStatus.notFound,
        detail: null,
        form: null,
        initialSnapshot: null,
        fieldErrors: const {},
        formError: null,
        failure: null,
        result: null,
        firstErrorField: null,
        isRetryInFlight: false,
      );

  const PlatformInstitutionEditState.accessDenied()
    : this._(
        status: PlatformInstitutionEditStatus.accessDenied,
        detail: null,
        form: null,
        initialSnapshot: null,
        fieldErrors: const {},
        formError: null,
        failure: null,
        result: null,
        firstErrorField: null,
        isRetryInFlight: false,
      );

  const PlatformInstitutionEditState.loadError(
    ApiFailure failure, {
    bool isRetryInFlight = false,
  }) : this._(
         status: PlatformInstitutionEditStatus.loadError,
         detail: null,
         form: null,
         initialSnapshot: null,
         fieldErrors: const {},
         formError: null,
         failure: failure,
         result: null,
         firstErrorField: null,
         isRetryInFlight: isRetryInFlight,
       );

  PlatformInstitutionEditState.success({
    required PlatformInstitutionDetail detail,
    required PlatformInstitutionEditFormValue form,
    required PlatformInstitutionEditSnapshot initialSnapshot,
    required PlatformInstitutionEditResult result,
  }) : this._(
         status: PlatformInstitutionEditStatus.success,
         detail: detail,
         form: form,
         initialSnapshot: initialSnapshot,
         fieldErrors: const {},
         formError: null,
         failure: null,
         result: result,
         firstErrorField: null,
         isRetryInFlight: false,
       );

  final PlatformInstitutionEditStatus status;
  final PlatformInstitutionDetail? detail;
  final PlatformInstitutionEditFormValue? form;
  final PlatformInstitutionEditSnapshot? initialSnapshot;
  final Map<PlatformInstitutionEditField, List<String>> fieldErrors;
  final String? formError;
  final ApiFailure? failure;
  final PlatformInstitutionEditResult? result;
  final PlatformInstitutionEditField? firstErrorField;
  final bool isRetryInFlight;

  bool get isSubmitting => status == PlatformInstitutionEditStatus.submitting;

  bool get isOutcomeUnknown {
    return status == PlatformInstitutionEditStatus.outcomeUnknown;
  }

  bool get isRequestInFlight {
    return status == PlatformInstitutionEditStatus.loading || isRetryInFlight;
  }

  bool get canSubmit {
    return form != null &&
        initialSnapshot != null &&
        !isSubmitting &&
        status != PlatformInstitutionEditStatus.success &&
        status != PlatformInstitutionEditStatus.outcomeUnknown;
  }

  bool get isDirty {
    final currentForm = form;
    final snapshot = initialSnapshot;
    return currentForm != null &&
        snapshot != null &&
        currentForm.isDirtyComparedTo(snapshot);
  }

  String? errorTextFor(PlatformInstitutionEditField field) {
    final errors = fieldErrors[field];
    if (errors == null || errors.isEmpty) {
      return null;
    }

    return errors.first;
  }

  PlatformInstitutionEditState retrying() {
    final currentFailure = failure;
    if (status != PlatformInstitutionEditStatus.loadError ||
        currentFailure == null) {
      return this;
    }

    return PlatformInstitutionEditState.loadError(
      currentFailure,
      isRetryInFlight: true,
    );
  }

  PlatformInstitutionEditState noChangesToSave() {
    final currentDetail = detail;
    final currentForm = form;
    final snapshot = initialSnapshot;
    if (currentDetail == null || currentForm == null || snapshot == null) {
      return this;
    }

    return PlatformInstitutionEditState.ready(
      detail: currentDetail,
      form: currentForm,
      initialSnapshot: snapshot,
      formError: 'No changes to save.',
    );
  }

  PlatformInstitutionEditState withForm(
    PlatformInstitutionEditFormValue nextForm, {
    PlatformInstitutionEditField? clearFieldError,
  }) {
    final currentDetail = detail;
    final snapshot = initialSnapshot;
    if (currentDetail == null || snapshot == null) {
      return this;
    }

    final errors = <PlatformInstitutionEditField, List<String>>{
      for (final entry in fieldErrors.entries) entry.key: entry.value,
    };

    if (clearFieldError != null) {
      errors.remove(clearFieldError);
    }

    if (errors.isEmpty) {
      return PlatformInstitutionEditState.ready(
        detail: currentDetail,
        form: nextForm,
        initialSnapshot: snapshot,
      );
    }

    return PlatformInstitutionEditState.validationFailure(
      detail: currentDetail,
      form: nextForm,
      initialSnapshot: snapshot,
      fieldErrors: errors,
      firstErrorField: _firstFieldIn(errors),
      formError: formError,
      failure: failure,
    );
  }

  static Map<PlatformInstitutionEditField, List<String>> _freezeFieldErrors(
    Map<PlatformInstitutionEditField, List<String>> fieldErrors,
  ) {
    final frozen = <PlatformInstitutionEditField, List<String>>{};

    for (final entry in fieldErrors.entries) {
      frozen[entry.key] = List<String>.unmodifiable(entry.value);
    }

    return Map<PlatformInstitutionEditField, List<String>>.unmodifiable(frozen);
  }

  static PlatformInstitutionEditField? _firstFieldIn(
    Map<PlatformInstitutionEditField, List<String>> fieldErrors,
  ) {
    for (final field in PlatformInstitutionEditField.values) {
      if (fieldErrors.containsKey(field)) {
        return field;
      }
    }

    return null;
  }
}
