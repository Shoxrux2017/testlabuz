import 'institution_user.dart';

enum InstitutionGroupMemberKind {
  teacher(
    endpointSegment: 'teachers',
    assignmentBodyKey: 'teacher_ids',
    candidateRole: InstitutionUserRole.teacher,
    sectionTitle: 'Teachers',
    singularTitle: 'Teacher',
  ),
  student(
    endpointSegment: 'students',
    assignmentBodyKey: 'student_ids',
    candidateRole: InstitutionUserRole.student,
    sectionTitle: 'Students',
    singularTitle: 'Student',
  );

  const InstitutionGroupMemberKind({
    required this.endpointSegment,
    required this.assignmentBodyKey,
    required this.candidateRole,
    required this.sectionTitle,
    required this.singularTitle,
  });

  final String endpointSegment;
  final String assignmentBodyKey;
  final InstitutionUserRole candidateRole;
  final String sectionTitle;
  final String singularTitle;

  String get assignTitle => 'Assign $sectionTitle';
  String get lowerSingular => singularTitle.toLowerCase();
  String get lowerPlural => sectionTitle.toLowerCase();
}

class InstitutionGroupMembership {
  const InstitutionGroupMembership({
    required this.id,
    required this.fullName,
    required this.loginName,
    required this.email,
    required this.phone,
    required this.isActive,
    required this.startedAt,
  });

  final String id;
  final String fullName;
  final String loginName;
  final String? email;
  final String? phone;
  final bool isActive;
  final DateTime startedAt;
}

class InstitutionGroupMembershipIdentity {
  InstitutionGroupMembershipIdentity({
    required this.groupId,
    required this.kind,
    required this.membership,
  }) : memberId = membership.id,
       startedAt = membership.startedAt;

  final String groupId;
  final InstitutionGroupMemberKind kind;
  final InstitutionGroupMembership membership;
  final String memberId;
  final DateTime startedAt;

  bool matches({
    required String currentGroupId,
    required InstitutionGroupMemberKind currentKind,
    required InstitutionGroupMembership currentMembership,
  }) {
    return groupId.toLowerCase() == currentGroupId.toLowerCase() &&
        kind == currentKind &&
        memberId.toLowerCase() == currentMembership.id.toLowerCase() &&
        startedAt == currentMembership.startedAt &&
        identical(membership, currentMembership);
  }
}
