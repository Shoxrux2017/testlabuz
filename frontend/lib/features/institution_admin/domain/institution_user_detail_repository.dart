import 'institution_user.dart';

abstract interface class InstitutionUserDetailRepository {
  Future<InstitutionUser> fetchUser(String userId);
}
