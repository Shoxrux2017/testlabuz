import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/institution_group.dart';
import '../domain/institution_group_create.dart';
import '../domain/institution_group_create_repository.dart';
import 'institution_group_create_remote_data_source.dart';

final institutionGroupCreateRepositoryProvider =
    Provider<InstitutionGroupCreateRepository>((ref) {
      return InstitutionGroupCreateRepositoryImpl(
        remoteDataSource: ref.watch(
          institutionGroupCreateRemoteDataSourceProvider,
        ),
      );
    });

class InstitutionGroupCreateRepositoryImpl
    implements InstitutionGroupCreateRepository {
  const InstitutionGroupCreateRepositoryImpl({required this.remoteDataSource});

  final InstitutionGroupCreateRemoteDataSource remoteDataSource;

  @override
  Future<InstitutionGroup> createGroup(
    InstitutionGroupCreateRequest request,
  ) async {
    final dto = await remoteDataSource.createGroup(request);
    final group = dto.group.toDomain();
    if (!request.snapshot.matches(group) ||
        group.status != InstitutionGroupStatus.active ||
        group.teachersCount != 0 ||
        group.studentsCount != 0 ||
        group.archivedAt != null) {
      throw const InstitutionGroupCreateOutcomeUnknownException();
    }

    return group;
  }
}
