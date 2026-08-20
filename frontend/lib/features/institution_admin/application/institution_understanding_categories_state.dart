import '../../../core/network/api_failure.dart';
import '../domain/institution_understanding_categories.dart';

enum InstitutionUnderstandingCategoriesStatus {
  initial,
  initialLoading,
  loadError,
  unconfiguredConfirmed,
  configuredConfirmed,
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

class InstitutionUnderstandingCategoriesState {
  const InstitutionUnderstandingCategoriesState._({
    required this.status,
    this.configuration,
    this.draft,
    this.fieldErrors = const {},
    this.setError,
    this.formError,
    this.notice,
    this.failure,
    this.focusField,
  });

  const InstitutionUnderstandingCategoriesState.initial()
    : this._(status: InstitutionUnderstandingCategoriesStatus.initial);

  const InstitutionUnderstandingCategoriesState.loading()
    : this._(status: InstitutionUnderstandingCategoriesStatus.initialLoading);

  const InstitutionUnderstandingCategoriesState.loadError(ApiFailure failure)
    : this._(
        status: InstitutionUnderstandingCategoriesStatus.loadError,
        failure: failure,
      );

  InstitutionUnderstandingCategoriesState.data(
    InstitutionUnderstandingCategoryConfiguration configuration, {
    String? notice,
  }) : this._(
         status: configuration.configured
             ? InstitutionUnderstandingCategoriesStatus.configuredConfirmed
             : InstitutionUnderstandingCategoriesStatus.unconfiguredConfirmed,
         configuration: configuration,
         notice: notice,
       );

  const InstitutionUnderstandingCategoriesState.refreshing(
    InstitutionUnderstandingCategoryConfiguration configuration,
  ) : this._(
        status: InstitutionUnderstandingCategoriesStatus.refreshing,
        configuration: configuration,
      );

  InstitutionUnderstandingCategoriesState.editing({
    required InstitutionUnderstandingCategoryConfiguration configuration,
    required InstitutionUnderstandingCategoryDraft draft,
    required bool dirty,
  }) : this._(
         status: dirty
             ? InstitutionUnderstandingCategoriesStatus.editingDirty
             : InstitutionUnderstandingCategoriesStatus.editingClean,
         configuration: configuration,
         draft: draft,
       );

  InstitutionUnderstandingCategoriesState.validationFailure({
    required this.configuration,
    required this.draft,
    required Map<InstitutionUnderstandingCategoryField, String> fieldErrors,
    this.setError,
    this.formError,
    this.focusField,
  }) : status = InstitutionUnderstandingCategoriesStatus.validationFailure,
       fieldErrors = Map.unmodifiable(fieldErrors),
       notice = null,
       failure = null;

  const InstitutionUnderstandingCategoriesState.submitting({
    required InstitutionUnderstandingCategoryConfiguration configuration,
    required InstitutionUnderstandingCategoryDraft draft,
  }) : this._(
         status: InstitutionUnderstandingCategoriesStatus.submitting,
         configuration: configuration,
         draft: draft,
       );

  const InstitutionUnderstandingCategoriesState.reconciling({
    required InstitutionUnderstandingCategoryConfiguration configuration,
    required InstitutionUnderstandingCategoryDraft draft,
  }) : this._(
         status:
             InstitutionUnderstandingCategoriesStatus.reconcilingCurrentState,
         configuration: configuration,
         draft: draft,
         notice:
             'The request result could not be confirmed. Checking current server categories…',
       );

  const InstitutionUnderstandingCategoriesState.definiteFailure({
    required InstitutionUnderstandingCategoryConfiguration configuration,
    required InstitutionUnderstandingCategoryDraft draft,
    required String formError,
  }) : this._(
         status: InstitutionUnderstandingCategoriesStatus.definiteFailure,
         configuration: configuration,
         draft: draft,
         formError: formError,
       );

  const InstitutionUnderstandingCategoriesState.unconfirmedCurrentState(
    InstitutionUnderstandingCategoryConfiguration configuration, {
    required String notice,
  }) : this._(
         status:
             InstitutionUnderstandingCategoriesStatus.unconfirmedCurrentState,
         configuration: configuration,
         notice: notice,
       );

  const InstitutionUnderstandingCategoriesState.unconfirmedWithoutCurrentState()
    : this._(
        status: InstitutionUnderstandingCategoriesStatus
            .unconfirmedWithoutCurrentState,
        notice:
            'The request result and current server categories could not be confirmed. Refresh before making a new change.',
      );

  const InstitutionUnderstandingCategoriesState.confirmedDirectSuccess(
    InstitutionUnderstandingCategoryConfiguration configuration,
  ) : this._(
        status: InstitutionUnderstandingCategoriesStatus.confirmedDirectSuccess,
        configuration: configuration,
        notice: 'Understanding categories saved.',
      );

  final InstitutionUnderstandingCategoriesStatus status;
  final InstitutionUnderstandingCategoryConfiguration? configuration;
  final InstitutionUnderstandingCategoryDraft? draft;
  final Map<InstitutionUnderstandingCategoryField, String> fieldErrors;
  final String? setError;
  final String? formError;
  final String? notice;
  final ApiFailure? failure;
  final InstitutionUnderstandingCategoryField? focusField;

  bool get isBusy =>
      status == InstitutionUnderstandingCategoriesStatus.refreshing ||
      status == InstitutionUnderstandingCategoriesStatus.submitting ||
      status ==
          InstitutionUnderstandingCategoriesStatus.reconcilingCurrentState;

  bool get isEditing =>
      status == InstitutionUnderstandingCategoriesStatus.editingClean ||
      status == InstitutionUnderstandingCategoriesStatus.editingDirty ||
      status == InstitutionUnderstandingCategoriesStatus.validationFailure ||
      status == InstitutionUnderstandingCategoriesStatus.definiteFailure;

  bool get isDirty =>
      status == InstitutionUnderstandingCategoriesStatus.editingDirty ||
      status == InstitutionUnderstandingCategoriesStatus.validationFailure ||
      status == InstitutionUnderstandingCategoriesStatus.definiteFailure;
}
