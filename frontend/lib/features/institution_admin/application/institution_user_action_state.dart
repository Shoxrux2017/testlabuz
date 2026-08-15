import '../domain/institution_user.dart';
import '../domain/institution_user_mutation.dart';

enum InstitutionUserActionStatus {
  idle,
  editing,
  lifecycleConfirming,
  submitting,
  reconcilingCurrentState,
  validationFailure,
  definiteFailure,
  unconfirmedCurrentState,
  confirmedDirectSuccess,
  targetNotFound,
}

class InstitutionUserActionState {
  InstitutionUserActionState._({
    required this.status,
    required this.selected,
    required this.form,
    required this.lifecycleAction,
    required this.fieldErrors,
    required this.formMessage,
    required this.feedback,
  });

  InstitutionUserActionState.idle()
    : this._(
        status: InstitutionUserActionStatus.idle,
        selected: null,
        form: null,
        lifecycleAction: null,
        fieldErrors: const {},
        formMessage: null,
        feedback: null,
      );

  InstitutionUserActionState.editing({
    required InstitutionUser selected,
    required InstitutionUserEditFormValue form,
    Map<InstitutionUserEditField, String> fieldErrors = const {},
    String? formMessage,
    InstitutionUserActionStatus status = InstitutionUserActionStatus.editing,
  }) : this._(
         status: status,
         selected: selected,
         form: form,
         lifecycleAction: null,
         fieldErrors: Map.unmodifiable(fieldErrors),
         formMessage: formMessage,
         feedback: null,
       );

  InstitutionUserActionState.lifecycle({
    required InstitutionUser selected,
    required InstitutionUserLifecycleAction action,
    required InstitutionUserActionStatus status,
    String? formMessage,
  }) : this._(
         status: status,
         selected: selected,
         form: null,
         lifecycleAction: action,
         fieldErrors: const {},
         formMessage: formMessage,
         feedback: null,
       );

  InstitutionUserActionState.feedback({
    required InstitutionUserActionStatus status,
    required String feedback,
    InstitutionUser? selected,
    InstitutionUserLifecycleAction? lifecycleAction,
  }) : this._(
         status: status,
         selected: selected,
         form: null,
         lifecycleAction: lifecycleAction,
         fieldErrors: const {},
         formMessage: null,
         feedback: feedback,
       );

  final InstitutionUserActionStatus status;
  final InstitutionUser? selected;
  final InstitutionUserEditFormValue? form;
  final InstitutionUserLifecycleAction? lifecycleAction;
  final Map<InstitutionUserEditField, String> fieldErrors;
  final String? formMessage;
  final String? feedback;

  bool get isBusy =>
      status == InstitutionUserActionStatus.submitting ||
      status == InstitutionUserActionStatus.reconcilingCurrentState;

  bool get isEditing =>
      status == InstitutionUserActionStatus.editing ||
      (status == InstitutionUserActionStatus.validationFailure &&
          form != null) ||
      (status == InstitutionUserActionStatus.definiteFailure && form != null);

  bool get isLifecycleDialog =>
      status == InstitutionUserActionStatus.lifecycleConfirming;

  String? errorFor(InstitutionUserEditField field) => fieldErrors[field];
}
