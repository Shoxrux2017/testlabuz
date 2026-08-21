import 'institution_user.dart';

enum InstitutionParentStudentPerspective {
  byParent(
    anchorRole: InstitutionUserRole.parent,
    anchorLabel: 'Parent',
    relatedLabel: 'Student',
  ),
  byStudent(
    anchorRole: InstitutionUserRole.student,
    anchorLabel: 'Student',
    relatedLabel: 'Parent',
  );

  const InstitutionParentStudentPerspective({
    required this.anchorRole,
    required this.anchorLabel,
    required this.relatedLabel,
  });

  final InstitutionUserRole anchorRole;
  final String anchorLabel;
  final String relatedLabel;
}

class InstitutionParentStudentRelatedUser {
  const InstitutionParentStudentRelatedUser({
    required this.id,
    required this.fullName,
    required this.loginName,
    required this.email,
    required this.phone,
    required this.isActive,
  });

  final String id;
  final String fullName;
  final String loginName;
  final String? email;
  final String? phone;
  final bool isActive;
}

class InstitutionParentStudentRelationship {
  const InstitutionParentStudentRelationship({
    required this.id,
    required this.parentId,
    required this.studentId,
    required this.startedAt,
    required this.endedAt,
    required this.relatedUser,
  });

  final String id;
  final String parentId;
  final String studentId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final InstitutionParentStudentRelatedUser relatedUser;
}

class InstitutionParentStudentRelationshipIdentity {
  InstitutionParentStudentRelationshipIdentity({
    required this.perspective,
    required this.anchor,
    required this.relationship,
  }) : anchorId = anchor.id,
       relationshipId = relationship.id,
       parentId = relationship.parentId,
       studentId = relationship.studentId,
       startedAt = relationship.startedAt;

  final InstitutionParentStudentPerspective perspective;
  final InstitutionUser anchor;
  final InstitutionParentStudentRelationship relationship;
  final String anchorId;
  final String relationshipId;
  final String parentId;
  final String studentId;
  final DateTime startedAt;

  bool matches({
    required InstitutionParentStudentPerspective currentPerspective,
    required InstitutionUser currentAnchor,
    required InstitutionParentStudentRelationship currentRelationship,
  }) {
    return perspective == currentPerspective &&
        identical(anchor, currentAnchor) &&
        anchorId.toLowerCase() == currentAnchor.id.toLowerCase() &&
        identical(relationship, currentRelationship) &&
        relationshipId.toLowerCase() == currentRelationship.id.toLowerCase() &&
        parentId.toLowerCase() == currentRelationship.parentId.toLowerCase() &&
        studentId.toLowerCase() ==
            currentRelationship.studentId.toLowerCase() &&
        startedAt == currentRelationship.startedAt;
  }
}
