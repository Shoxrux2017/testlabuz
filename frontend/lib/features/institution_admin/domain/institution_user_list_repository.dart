import 'institution_user_list.dart';
import 'institution_user_list_query.dart';

abstract interface class InstitutionUserListRepository {
  Future<InstitutionUserListPage> fetchUsers(InstitutionUserListQuery query);
}
