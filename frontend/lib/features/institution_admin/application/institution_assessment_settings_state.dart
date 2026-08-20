import '../../../core/network/api_failure.dart';
import '../domain/institution_assessment_settings.dart';

enum InstitutionAssessmentSettingsStatus {
  initial,
  initialLoading,
  loadError,
  confirmedData,
  refreshing,
  editingClean,
  editingDirty,
  validationFailure,
  submitting,
  reconcilingCurrentState,
  definiteFailure,
  unconfirmedCurrentState,
  unconfirmedWithoutCurrentState,
  confirmedDirectSuccess,
}

class InstitutionAssessmentSettingsState {
  const InstitutionAssessmentSettingsState._({
    required this.status,
    this.settings,
    this.draft,
    this.fieldErrors = const {},
    this.formError,
    this.notice,
    this.failure,
    this.focusField,
  });

  const InstitutionAssessmentSettingsState.initial()
    : this._(status: InstitutionAssessmentSettingsStatus.initial);

  const InstitutionAssessmentSettingsState.loading()
    : this._(status: InstitutionAssessmentSettingsStatus.initialLoading);

  const InstitutionAssessmentSettingsState.loadError(ApiFailure failure)
    : this._(
        status: InstitutionAssessmentSettingsStatus.loadError,
        failure: failure,
      );

  const InstitutionAssessmentSettingsState.data(
    InstitutionAssessmentSettings settings, {
    String? notice,
  }) : this._(
         status: InstitutionAssessmentSettingsStatus.confirmedData,
         settings: settings,
         notice: notice,
       );

  const InstitutionAssessmentSettingsState.refreshing(
    InstitutionAssessmentSettings settings,
  ) : this._(
        status: InstitutionAssessmentSettingsStatus.refreshing,
        settings: settings,
      );

  InstitutionAssessmentSettingsState.editing({
    required InstitutionAssessmentSettings settings,
    required InstitutionAssessmentSettingsDraft draft,
    required bool dirty,
  }) : this._(
         status: dirty
             ? InstitutionAssessmentSettingsStatus.editingDirty
             : InstitutionAssessmentSettingsStatus.editingClean,
         settings: settings,
         draft: draft,
       );

  InstitutionAssessmentSettingsState.validationFailure({
    required InstitutionAssessmentSettings settings,
    required InstitutionAssessmentSettingsDraft draft,
    required Map<InstitutionAssessmentSettingsField, String> fieldErrors,
    String? formError,
    InstitutionAssessmentSettingsField? focusField,
  }) : this._(
         status: InstitutionAssessmentSettingsStatus.validationFailure,
         settings: settings,
         draft: draft,
         fieldErrors: Map.unmodifiable(fieldErrors),
         formError: formError,
         focusField: focusField,
       );

  const InstitutionAssessmentSettingsState.submitting({
    required InstitutionAssessmentSettings settings,
    required InstitutionAssessmentSettingsDraft draft,
  }) : this._(
         status: InstitutionAssessmentSettingsStatus.submitting,
         settings: settings,
         draft: draft,
       );

  const InstitutionAssessmentSettingsState.reconciling({
    required InstitutionAssessmentSettings settings,
    required InstitutionAssessmentSettingsDraft draft,
  }) : this._(
         status: InstitutionAssessmentSettingsStatus.reconcilingCurrentState,
         settings: settings,
         draft: draft,
         notice:
             'The request result could not be confirmed. Checking the current server state…',
       );

  const InstitutionAssessmentSettingsState.definiteFailure({
    required InstitutionAssessmentSettings settings,
    required InstitutionAssessmentSettingsDraft draft,
    required String formError,
  }) : this._(
         status: InstitutionAssessmentSettingsStatus.definiteFailure,
         settings: settings,
         draft: draft,
         formError: formError,
       );

  const InstitutionAssessmentSettingsState.unconfirmedCurrentState(
    InstitutionAssessmentSettings settings, {
    required String notice,
  }) : this._(
         status: InstitutionAssessmentSettingsStatus.unconfirmedCurrentState,
         settings: settings,
         notice: notice,
       );

  const InstitutionAssessmentSettingsState.unconfirmedWithoutCurrentState()
    : this._(
        status:
            InstitutionAssessmentSettingsStatus.unconfirmedWithoutCurrentState,
        notice:
            'The request result and current server settings could not be confirmed. Refresh before making a new change.',
      );

  const InstitutionAssessmentSettingsState.confirmedDirectSuccess(
    InstitutionAssessmentSettings settings,
  ) : this._(
        status: InstitutionAssessmentSettingsStatus.confirmedDirectSuccess,
        settings: settings,
        notice: 'Assessment settings saved.',
      );

  final InstitutionAssessmentSettingsStatus status;
  final InstitutionAssessmentSettings? settings;
  final InstitutionAssessmentSettingsDraft? draft;
  final Map<InstitutionAssessmentSettingsField, String> fieldErrors;
  final String? formError;
  final String? notice;
  final ApiFailure? failure;
  final InstitutionAssessmentSettingsField? focusField;

  bool get isBusy =>
      status == InstitutionAssessmentSettingsStatus.refreshing ||
      status == InstitutionAssessmentSettingsStatus.submitting ||
      status == InstitutionAssessmentSettingsStatus.reconcilingCurrentState;

  bool get isEditing =>
      status == InstitutionAssessmentSettingsStatus.editingClean ||
      status == InstitutionAssessmentSettingsStatus.editingDirty ||
      status == InstitutionAssessmentSettingsStatus.validationFailure ||
      status == InstitutionAssessmentSettingsStatus.definiteFailure;

  bool get isDirty =>
      status == InstitutionAssessmentSettingsStatus.editingDirty ||
      status == InstitutionAssessmentSettingsStatus.validationFailure ||
      status == InstitutionAssessmentSettingsStatus.definiteFailure;
}
