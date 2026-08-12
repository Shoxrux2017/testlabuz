import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/platform_institution_create.dart';
import '../domain/platform_institution_create_repository.dart';
import 'platform_institution_create_remote_data_source.dart';

final platformInstitutionCreateRepositoryProvider =
    Provider<PlatformInstitutionCreateRepository>((ref) {
      return PlatformInstitutionCreateRepositoryImpl(
        remoteDataSource: ref.watch(
          platformInstitutionCreateRemoteDataSourceProvider,
        ),
      );
    });

class PlatformInstitutionCreateRepositoryImpl
    implements PlatformInstitutionCreateRepository {
  const PlatformInstitutionCreateRepositoryImpl({
    required this.remoteDataSource,
  });

  final PlatformInstitutionCreateRemoteDataSource remoteDataSource;

  @override
  Future<PlatformInstitutionCreateResult> createInstitution(
    PlatformInstitutionCreateRequest request,
  ) async {
    final dto = await remoteDataSource.createInstitution(request);

    return dto.toDomain();
  }
}
