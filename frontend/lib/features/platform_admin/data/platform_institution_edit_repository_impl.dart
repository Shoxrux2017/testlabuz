import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/platform_institution_edit.dart';
import '../domain/platform_institution_edit_repository.dart';
import 'platform_institution_edit_remote_data_source.dart';

final platformInstitutionEditRepositoryProvider =
    Provider<PlatformInstitutionEditRepository>((ref) {
      return PlatformInstitutionEditRepositoryImpl(
        remoteDataSource: ref.watch(
          platformInstitutionEditRemoteDataSourceProvider,
        ),
      );
    });

class PlatformInstitutionEditRepositoryImpl
    implements PlatformInstitutionEditRepository {
  const PlatformInstitutionEditRepositoryImpl({required this.remoteDataSource});

  final PlatformInstitutionEditRemoteDataSource remoteDataSource;

  @override
  Future<PlatformInstitutionEditResult> updateInstitution(
    String institutionId,
    PlatformInstitutionEditRequest request,
  ) async {
    final dto = await remoteDataSource.updateInstitution(
      institutionId,
      request,
    );

    return dto.toDomain();
  }
}
