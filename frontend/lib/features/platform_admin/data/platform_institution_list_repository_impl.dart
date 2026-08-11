import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/platform_institution_list.dart';
import '../domain/platform_institution_list_query.dart';
import '../domain/platform_institution_list_repository.dart';
import 'platform_institution_list_remote_data_source.dart';

final platformInstitutionListRepositoryProvider =
    Provider<PlatformInstitutionListRepository>((ref) {
      return PlatformInstitutionListRepositoryImpl(
        remoteDataSource: ref.watch(
          platformInstitutionListRemoteDataSourceProvider,
        ),
      );
    });

class PlatformInstitutionListRepositoryImpl
    implements PlatformInstitutionListRepository {
  const PlatformInstitutionListRepositoryImpl({required this.remoteDataSource});

  final PlatformInstitutionListRemoteDataSource remoteDataSource;

  @override
  Future<PlatformInstitutionListPage> fetchInstitutions(
    PlatformInstitutionListQuery query,
  ) async {
    final dto = await remoteDataSource.fetchInstitutions(query);

    return dto.toDomain();
  }
}
