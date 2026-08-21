import 'institution_group_membership.dart';
import 'institution_group_membership_list.dart';
import 'institution_group_membership_mutation.dart';
import 'institution_group_membership_query.dart';

abstract interface class InstitutionGroupMembershipRepository {
  Future<InstitutionGroupMembershipListPage> fetchMemberships({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembershipQuery query,
  });

  Future<List<InstitutionGroupMembership>> assignMemberships({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required InstitutionGroupMembershipAssignmentRequest request,
  });

  Future<void> removeMembership({
    required String groupId,
    required InstitutionGroupMemberKind kind,
    required String memberId,
  });
}
