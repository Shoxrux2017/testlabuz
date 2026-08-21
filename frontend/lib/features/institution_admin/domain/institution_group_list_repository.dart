import 'institution_group_list.dart';
import 'institution_group_list_query.dart';

abstract interface class InstitutionGroupListRepository {
  Future<InstitutionGroupListPage> fetchGroups(InstitutionGroupListQuery query);
}
