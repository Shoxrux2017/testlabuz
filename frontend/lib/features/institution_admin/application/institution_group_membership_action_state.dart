import '../domain/institution_group.dart';
import '../domain/institution_group_membership.dart';

enum InstitutionGroupMembershipActionKind { assign, remove }

enum InstitutionGroupMembershipActionStatus {
  idle,
  assignOpen,
  removeConfirming,
  submitting,
  reconcilingCurrentState,
  recoverableFailure,
  terminalFeedback,
}

class InstitutionGroupMembershipActionState {
  const InstitutionGroupMembershipActionState._({
    required this.status,
    required this.actionKind,
    required this.memberKind,
    required this.group,
    required this.membership,
    required this.formMessage,
    required this.feedback,
  });

  const InstitutionGroupMembershipActionState.idle()
    : this._(
        status: InstitutionGroupMembershipActionStatus.idle,
        actionKind: null,
        memberKind: null,
        group: null,
        membership: null,
        formMessage: null,
        feedback: null,
      );

  const InstitutionGroupMembershipActionState.assign({
    required InstitutionGroupMembershipActionStatus status,
    required InstitutionGroupMemberKind memberKind,
    required InstitutionGroup group,
    String? formMessage,
  }) : this._(
         status: status,
         actionKind: InstitutionGroupMembershipActionKind.assign,
         memberKind: memberKind,
         group: group,
         membership: null,
         formMessage: formMessage,
         feedback: null,
       );

  const InstitutionGroupMembershipActionState.remove({
    required InstitutionGroupMembershipActionStatus status,
    required InstitutionGroupMemberKind memberKind,
    required InstitutionGroup group,
    required InstitutionGroupMembership membership,
    String? formMessage,
  }) : this._(
         status: status,
         actionKind: InstitutionGroupMembershipActionKind.remove,
         memberKind: memberKind,
         group: group,
         membership: membership,
         formMessage: formMessage,
         feedback: null,
       );

  const InstitutionGroupMembershipActionState.reconciling({
    required InstitutionGroupMembershipActionKind actionKind,
    required InstitutionGroupMemberKind memberKind,
    required InstitutionGroup group,
  }) : this._(
         status: InstitutionGroupMembershipActionStatus.reconcilingCurrentState,
         actionKind: actionKind,
         memberKind: memberKind,
         group: group,
         membership: null,
         formMessage: null,
         feedback: null,
       );

  const InstitutionGroupMembershipActionState.feedback({
    required String feedback,
    InstitutionGroupMembershipActionKind? actionKind,
    InstitutionGroupMemberKind? memberKind,
  }) : this._(
         status: InstitutionGroupMembershipActionStatus.terminalFeedback,
         actionKind: actionKind,
         memberKind: memberKind,
         group: null,
         membership: null,
         formMessage: null,
         feedback: feedback,
       );

  final InstitutionGroupMembershipActionStatus status;
  final InstitutionGroupMembershipActionKind? actionKind;
  final InstitutionGroupMemberKind? memberKind;
  final InstitutionGroup? group;
  final InstitutionGroupMembership? membership;
  final String? formMessage;
  final String? feedback;

  bool get isBusy =>
      status == InstitutionGroupMembershipActionStatus.submitting ||
      status == InstitutionGroupMembershipActionStatus.reconcilingCurrentState;

  bool get isReconciling =>
      status == InstitutionGroupMembershipActionStatus.reconcilingCurrentState;

  bool get isAssignDialog =>
      actionKind == InstitutionGroupMembershipActionKind.assign &&
      (status == InstitutionGroupMembershipActionStatus.assignOpen ||
          status == InstitutionGroupMembershipActionStatus.submitting ||
          status == InstitutionGroupMembershipActionStatus.recoverableFailure);

  bool get isRemoveDialog =>
      actionKind == InstitutionGroupMembershipActionKind.remove &&
      (status == InstitutionGroupMembershipActionStatus.removeConfirming ||
          status == InstitutionGroupMembershipActionStatus.submitting);

  bool get hasOpenAction => isAssignDialog || isRemoveDialog || isReconciling;
}
