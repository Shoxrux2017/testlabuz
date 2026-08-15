import 'institution_user.dart';
import 'institution_user_create.dart';

abstract interface class InstitutionUserCreateRepository {
  Future<InstitutionUser> createUser(InstitutionUserCreateRequest request);
}
