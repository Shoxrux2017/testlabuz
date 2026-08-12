import 'platform_institution_admin_create.dart';
import 'platform_institution_admin_list.dart';
import 'platform_institution_admin_list_query.dart';

abstract interface class PlatformInstitutionAdminRepository {
  Future<PlatformInstitutionAdminList> fetchAdmins({
    required String institutionId,
    required PlatformInstitutionAdminListQuery query,
  });

  Future<PlatformInstitutionAdminCreateResult> createAdmin({
    required String institutionId,
    required PlatformInstitutionAdminCreateRequest request,
  });
}
