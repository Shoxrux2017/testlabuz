import 'platform_institution_admin_create.dart';
import 'platform_institution_admin_lifecycle.dart';
import 'platform_institution_admin_list.dart';
import 'platform_institution_admin_list_query.dart';
import 'platform_institution_admin_update.dart';

abstract interface class PlatformInstitutionAdminRepository {
  Future<PlatformInstitutionAdminList> fetchAdmins({
    required String institutionId,
    required PlatformInstitutionAdminListQuery query,
  });

  Future<PlatformInstitutionAdminCreateResult> createAdmin({
    required String institutionId,
    required PlatformInstitutionAdminCreateRequest request,
  });

  Future<PlatformInstitutionAdminUpdateResult> updateAdmin({
    required String adminId,
    required PlatformInstitutionAdminUpdateRequest request,
  });

  Future<PlatformInstitutionAdminLifecycleResult> activateAdmin({
    required String adminId,
  });

  Future<PlatformInstitutionAdminLifecycleResult> deactivateAdmin({
    required String adminId,
  });
}
