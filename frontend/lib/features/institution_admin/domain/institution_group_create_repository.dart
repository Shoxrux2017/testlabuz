import 'institution_group.dart';
import 'institution_group_create.dart';

abstract interface class InstitutionGroupCreateRepository {
  Future<InstitutionGroup> createGroup(InstitutionGroupCreateRequest request);
}
