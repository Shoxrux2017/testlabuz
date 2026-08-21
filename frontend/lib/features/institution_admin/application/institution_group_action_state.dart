import '../domain/institution_group.dart';
import '../domain/institution_group_mutation.dart';

enum InstitutionGroupActionKind { edit, archive }

enum InstitutionGroupActionStatus {
  idle,
  editing,
  archiveConfirming,
  submitting,
  reconcilingCurrentState,
  validationFailure,
  definiteFailure,
  unconfirmedCurrentState,
  confirmedDirectSuccess,
}

class InstitutionGroupActionState {
  InstitutionGroupActionState._({
    required this.status,
    required this.kind,
    required this.selected,
    required this.form,
    required this.fieldErrors,
    required this.formMessage,
    required this.feedback,
  });

  InstitutionGroupActionState.idle()
    : this._(
        status: InstitutionGroupActionStatus.idle,
        kind: null,
        selected: null,
        form: null,
        fieldErrors: const {},
        formMessage: null,
        feedback: null,
      );

  InstitutionGroupActionState.editing({
    required InstitutionGroup selected,
    required InstitutionGroupEditFormValue form,
    Map<InstitutionGroupEditField, String> fieldErrors = const {},
    String? formMessage,
    InstitutionGroupActionStatus status = InstitutionGroupActionStatus.editing,
  }) : this._(
         status: status,
         kind: InstitutionGroupActionKind.edit,
         selected: selected,
         form: form,
         fieldErrors: Map.unmodifiable(fieldErrors),
         formMessage: formMessage,
         feedback: null,
       );

  InstitutionGroupActionState.archive({
    required InstitutionGroup selected,
    required InstitutionGroupActionStatus status,
    String? formMessage,
  }) : this._(
         status: status,
         kind: InstitutionGroupActionKind.archive,
         selected: selected,
         form: null,
         fieldErrors: const {},
         formMessage: formMessage,
         feedback: null,
       );

  InstitutionGroupActionState.feedback({
    required InstitutionGroupActionStatus status,
    required String feedback,
    InstitutionGroup? selected,
    InstitutionGroupActionKind? kind,
  }) : this._(
         status: status,
         kind: kind,
         selected: selected,
         form: null,
         fieldErrors: const {},
         formMessage: null,
         feedback: feedback,
       );

  final InstitutionGroupActionStatus status;
  final InstitutionGroupActionKind? kind;
  final InstitutionGroup? selected;
  final InstitutionGroupEditFormValue? form;
  final Map<InstitutionGroupEditField, String> fieldErrors;
  final String? formMessage;
  final String? feedback;

  bool get isBusy =>
      status == InstitutionGroupActionStatus.submitting ||
      status == InstitutionGroupActionStatus.reconcilingCurrentState;

  bool get isReconciling =>
      status == InstitutionGroupActionStatus.reconcilingCurrentState;

  bool get isEditing =>
      kind == InstitutionGroupActionKind.edit &&
      (status == InstitutionGroupActionStatus.editing ||
          status == InstitutionGroupActionStatus.validationFailure ||
          status == InstitutionGroupActionStatus.definiteFailure ||
          isBusy);

  bool get isArchiveDialog =>
      kind == InstitutionGroupActionKind.archive &&
      (status == InstitutionGroupActionStatus.archiveConfirming || isBusy);

  bool get hasOpenAction => isEditing || isArchiveDialog;

  String? errorFor(InstitutionGroupEditField field) => fieldErrors[field];
}
