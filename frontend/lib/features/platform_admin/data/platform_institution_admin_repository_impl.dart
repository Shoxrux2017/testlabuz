import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/platform_institution_admin_create.dart';
import '../domain/platform_institution_admin_lifecycle.dart';
import '../domain/platform_institution_admin_list.dart';
import '../domain/platform_institution_admin_list_query.dart';
import '../domain/platform_institution_admin_repository.dart';
import '../domain/platform_institution_admin_update.dart';
import 'platform_institution_admin_remote_data_source.dart';

final platformInstitutionAdminRepositoryProvider =
    Provider<PlatformInstitutionAdminRepository>((ref) {
      return PlatformInstitutionAdminRepositoryImpl(
        remoteDataSource: ref.watch(
          platformInstitutionAdminRemoteDataSourceProvider,
        ),
      );
    });

class PlatformInstitutionAdminRepositoryImpl
    implements PlatformInstitutionAdminRepository {
  const PlatformInstitutionAdminRepositoryImpl({
    required this.remoteDataSource,
  });

  final PlatformInstitutionAdminRemoteDataSource remoteDataSource;

  @override
  Future<PlatformInstitutionAdminList> fetchAdmins({
    required String institutionId,
    required PlatformInstitutionAdminListQuery query,
  }) async {
    final dto = await remoteDataSource.fetchAdmins(
      institutionId: institutionId,
      query: query,
    );

    return dto.toDomain();
  }

  @override
  Future<PlatformInstitutionAdminCreateResult> createAdmin({
    required String institutionId,
    required PlatformInstitutionAdminCreateRequest request,
  }) async {
    final dto = await remoteDataSource.createAdmin(
      institutionId: institutionId,
      request: request,
    );

    return dto.toDomain();
  }

  @override
  Future<PlatformInstitutionAdminUpdateResult> updateAdmin({
    required String adminId,
    required PlatformInstitutionAdminUpdateRequest request,
  }) async {
    final dto = await remoteDataSource.updateAdmin(
      adminId: adminId,
      request: request,
    );

    return dto.toDomain();
  }

  @override
  Future<PlatformInstitutionAdminLifecycleResult> activateAdmin({
    required String adminId,
  }) async {
    final dto = await remoteDataSource.activateAdmin(adminId: adminId);

    return dto.toDomain();
  }

  @override
  Future<PlatformInstitutionAdminLifecycleResult> deactivateAdmin({
    required String adminId,
  }) async {
    final dto = await remoteDataSource.deactivateAdmin(adminId: adminId);

    return dto.toDomain();
  }
}
