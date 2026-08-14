import '../../../core/network/api_failure.dart';
import '../domain/institution_profile.dart';
import '../domain/institution_profile_update.dart';

enum InstitutionProfileViewStatus {
  initial,
  loading,
  data,
  editing,
  submitting,
  validationFailure,
  mutationFailure,
  reconciling,
  confirmedDirectSuccess,
  unconfirmedCurrentState,
  outcomeUnknown,
  loadError,
}

enum InstitutionProfileFailureOperation { load, mutation }

class InstitutionProfileState {
  const InstitutionProfileState._({
    required this.status,
    this.profile,
    this.form,
    this.baseline,
    this.fieldErrors = const {},
    this.formError,
    this.notice,
    this.failure,
    this.failureOperation,
    this.isRetryInFlight = false,
    this.isReloadInFlight = false,
    this.focusField,
  });

  const InstitutionProfileState.initial()
    : this._(status: InstitutionProfileViewStatus.initial);

  const InstitutionProfileState.loading()
    : this._(status: InstitutionProfileViewStatus.loading);

  const InstitutionProfileState.data(
    InstitutionProfile profile, {
    String? notice,
  }) : this._(
         status: InstitutionProfileViewStatus.data,
         profile: profile,
         notice: notice,
       );

  InstitutionProfileState.editing({
    required InstitutionProfile profile,
    required InstitutionProfileEditFormValue form,
    required InstitutionProfileEditSnapshot baseline,
  }) : this._(
         status: InstitutionProfileViewStatus.editing,
         profile: profile,
         form: form,
         baseline: baseline,
       );

  InstitutionProfileState.submitting({
    required InstitutionProfile profile,
    required InstitutionProfileEditFormValue form,
    required InstitutionProfileEditSnapshot baseline,
  }) : this._(
         status: InstitutionProfileViewStatus.submitting,
         profile: profile,
         form: form,
         baseline: baseline,
       );

  InstitutionProfileState.validationFailure({
    required InstitutionProfile profile,
    required InstitutionProfileEditFormValue form,
    required InstitutionProfileEditSnapshot baseline,
    required Map<InstitutionProfileEditField, String> fieldErrors,
    String? formError,
    InstitutionProfileEditField? focusField,
  }) : this._(
         status: InstitutionProfileViewStatus.validationFailure,
         profile: profile,
         form: form,
         baseline: baseline,
         fieldErrors: Map.unmodifiable(fieldErrors),
         formError: formError,
         focusField: focusField,
       );

  InstitutionProfileState.mutationFailure({
    required InstitutionProfile profile,
    required InstitutionProfileEditFormValue form,
    required InstitutionProfileEditSnapshot baseline,
    required String formError,
  }) : this._(
         status: InstitutionProfileViewStatus.mutationFailure,
         profile: profile,
         form: form,
         baseline: baseline,
         formError: formError,
       );

  InstitutionProfileState.reconciling({
    required InstitutionProfile profile,
    required InstitutionProfileEditFormValue form,
    required InstitutionProfileEditSnapshot baseline,
  }) : this._(
         status: InstitutionProfileViewStatus.reconciling,
         profile: profile,
         form: form,
         baseline: baseline,
       );

  const InstitutionProfileState.confirmedDirectSuccess(
    InstitutionProfile profile,
  ) : this._(
        status: InstitutionProfileViewStatus.confirmedDirectSuccess,
        profile: profile,
        notice: 'Institution profile updated.',
      );

  const InstitutionProfileState.unconfirmedCurrentState(
    InstitutionProfile profile, {
    required String notice,
  }) : this._(
         status: InstitutionProfileViewStatus.unconfirmedCurrentState,
         profile: profile,
         notice: notice,
       );

  const InstitutionProfileState.outcomeUnknown({bool isReloadInFlight = false})
    : this._(
        status: InstitutionProfileViewStatus.outcomeUnknown,
        isReloadInFlight: isReloadInFlight,
      );

  const InstitutionProfileState.loadError(
    ApiFailure failure, {
    required InstitutionProfileFailureOperation operation,
    bool isRetryInFlight = false,
  }) : this._(
         status: InstitutionProfileViewStatus.loadError,
         failure: failure,
         failureOperation: operation,
         isRetryInFlight: isRetryInFlight,
       );

  final InstitutionProfileViewStatus status;
  final InstitutionProfile? profile;
  final InstitutionProfileEditFormValue? form;
  final InstitutionProfileEditSnapshot? baseline;
  final Map<InstitutionProfileEditField, String> fieldErrors;
  final String? formError;
  final String? notice;
  final ApiFailure? failure;
  final InstitutionProfileFailureOperation? failureOperation;
  final bool isRetryInFlight;
  final bool isReloadInFlight;
  final InstitutionProfileEditField? focusField;
}
