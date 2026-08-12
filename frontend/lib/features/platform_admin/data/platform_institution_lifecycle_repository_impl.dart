import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/platform_institution_lifecycle.dart';
import '../domain/platform_institution_lifecycle_repository.dart';
import 'platform_institution_lifecycle_remote_data_source.dart';

final platformInstitutionLifecycleRepositoryProvider =
    Provider<PlatformInstitutionLifecycleRepository>((ref) {
      return PlatformInstitutionLifecycleRepositoryImpl(
        remoteDataSource: ref.watch(
          platformInstitutionLifecycleRemoteDataSourceProvider,
        ),
      );
    });

class PlatformInstitutionLifecycleRepositoryImpl
    implements PlatformInstitutionLifecycleRepository {
  const PlatformInstitutionLifecycleRepositoryImpl({
    required this.remoteDataSource,
  });

  final PlatformInstitutionLifecycleRemoteDataSource remoteDataSource;

  @override
  Future<PlatformInstitutionLifecycleResult> activateInstitution(
    String institutionId,
  ) async {
    final dto = await remoteDataSource.activateInstitution(institutionId);

    return dto.toDomain();
  }

  @override
  Future<PlatformInstitutionLifecycleResult> deactivateInstitution(
    String institutionId,
  ) async {
    final dto = await remoteDataSource.deactivateInstitution(institutionId);

    return dto.toDomain();
  }
}
