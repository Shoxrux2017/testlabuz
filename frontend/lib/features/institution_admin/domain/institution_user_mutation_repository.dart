import 'institution_user.dart';
import 'institution_user_mutation.dart';

abstract interface class InstitutionUserMutationRepository {
  Future<InstitutionUser> updateUser(
    String userId,
    InstitutionUser selected,
    InstitutionUserEditRequest request,
  );

  Future<InstitutionUser> changeLifecycle(
    String userId,
    InstitutionUser selected,
    InstitutionUserLifecycleAction action,
  );
}
