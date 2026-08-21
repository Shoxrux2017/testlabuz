import 'institution_group.dart';

abstract interface class InstitutionGroupDetailRepository {
  Future<InstitutionGroup> fetchGroup(String groupId);
}
