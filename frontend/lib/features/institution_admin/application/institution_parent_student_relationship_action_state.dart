import '../domain/institution_parent_student_relationship.dart';
import '../domain/institution_user.dart';

enum InstitutionParentStudentRelationshipActionStatus {
  idle,
  connectDialog,
  connectRecoverableFailure,
  submittingConnect,
  disconnectDialog,
  submittingDisconnect,
  reconciling,
  feedback,
}

class InstitutionParentStudentRelationshipActionState {
  const InstitutionParentStudentRelationshipActionState._({
    required this.status,
    required this.perspective,
    required this.anchor,
    required this.relationship,
    required this.parent,
    required this.student,
    required this.formMessage,
    required this.parentError,
    required this.studentError,
    required this.feedback,
  });

  const InstitutionParentStudentRelationshipActionState.idle()
    : this._(
        status: InstitutionParentStudentRelationshipActionStatus.idle,
        perspective: null,
        anchor: null,
        relationship: null,
        parent: null,
        student: null,
        formMessage: null,
        parentError: null,
        studentError: null,
        feedback: null,
      );

  const InstitutionParentStudentRelationshipActionState.connect({
    InstitutionParentStudentRelationshipActionStatus status =
        InstitutionParentStudentRelationshipActionStatus.connectDialog,
    InstitutionUser? parent,
    InstitutionUser? student,
    String? formMessage,
    String? parentError,
    String? studentError,
  }) : this._(
         status: status,
         perspective: null,
         anchor: null,
         relationship: null,
         parent: parent,
         student: student,
         formMessage: formMessage,
         parentError: parentError,
         studentError: studentError,
         feedback: null,
       );

  const InstitutionParentStudentRelationshipActionState.disconnect({
    required InstitutionParentStudentRelationshipActionStatus status,
    required InstitutionParentStudentPerspective perspective,
    required InstitutionUser anchor,
    required InstitutionParentStudentRelationship relationship,
  }) : this._(
         status: status,
         perspective: perspective,
         anchor: anchor,
         relationship: relationship,
         parent: null,
         student: null,
         formMessage: null,
         parentError: null,
         studentError: null,
         feedback: null,
       );

  const InstitutionParentStudentRelationshipActionState.reconciling({
    required String feedback,
    InstitutionParentStudentPerspective? perspective,
  }) : this._(
         status: InstitutionParentStudentRelationshipActionStatus.reconciling,
         perspective: perspective,
         anchor: null,
         relationship: null,
         parent: null,
         student: null,
         formMessage: null,
         parentError: null,
         studentError: null,
         feedback: feedback,
       );

  const InstitutionParentStudentRelationshipActionState.feedback(
    String feedback,
  ) : this._(
        status: InstitutionParentStudentRelationshipActionStatus.feedback,
        perspective: null,
        anchor: null,
        relationship: null,
        parent: null,
        student: null,
        formMessage: null,
        parentError: null,
        studentError: null,
        feedback: feedback,
      );

  final InstitutionParentStudentRelationshipActionStatus status;
  final InstitutionParentStudentPerspective? perspective;
  final InstitutionUser? anchor;
  final InstitutionParentStudentRelationship? relationship;
  final InstitutionUser? parent;
  final InstitutionUser? student;
  final String? formMessage;
  final String? parentError;
  final String? studentError;
  final String? feedback;

  bool get isConnectDialog =>
      status ==
          InstitutionParentStudentRelationshipActionStatus.connectDialog ||
      status ==
          InstitutionParentStudentRelationshipActionStatus
              .connectRecoverableFailure ||
      status ==
          InstitutionParentStudentRelationshipActionStatus.submittingConnect;

  bool get isDisconnectDialog =>
      status ==
          InstitutionParentStudentRelationshipActionStatus.disconnectDialog ||
      status ==
          InstitutionParentStudentRelationshipActionStatus.submittingDisconnect;

  bool get isBusy =>
      status ==
          InstitutionParentStudentRelationshipActionStatus.submittingConnect ||
      status ==
          InstitutionParentStudentRelationshipActionStatus
              .submittingDisconnect ||
      status == InstitutionParentStudentRelationshipActionStatus.reconciling;

  bool get hasOpenAction => isConnectDialog || isDisconnectDialog || isBusy;
}
