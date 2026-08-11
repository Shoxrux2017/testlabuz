import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/platform_institution_detail.dart';
import '../domain/platform_institution_detail_repository.dart';
import 'platform_institution_detail_remote_data_source.dart';

final platformInstitutionDetailRepositoryProvider =
    Provider<PlatformInstitutionDetailRepository>((ref) {
      return PlatformInstitutionDetailRepositoryImpl(
        remoteDataSource: ref.watch(
          platformInstitutionDetailRemoteDataSourceProvider,
        ),
      );
    });

class PlatformInstitutionDetailRepositoryImpl
    implements PlatformInstitutionDetailRepository {
  const PlatformInstitutionDetailRepositoryImpl({
    required this.remoteDataSource,
  });

  final PlatformInstitutionDetailRemoteDataSource remoteDataSource;

  @override
  Future<PlatformInstitutionDetail> fetchInstitutionDetail(
    String institutionId,
  ) async {
    final dto = await remoteDataSource.fetchInstitutionDetail(institutionId);

    return dto.toDomain();
  }
}
