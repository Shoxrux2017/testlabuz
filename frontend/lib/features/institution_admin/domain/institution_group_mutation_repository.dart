import 'institution_group.dart';
import 'institution_group_mutation.dart';

abstract interface class InstitutionGroupMutationRepository {
  Future<InstitutionGroup> updateGroup(
    String groupId,
    InstitutionGroup selected,
    InstitutionGroupEditRequest request,
  );

  Future<InstitutionGroup> archiveGroup(
    String groupId,
    InstitutionGroup selected,
  );
}
