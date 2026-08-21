import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/institution_group_list.dart';
import '../domain/institution_group_list_query.dart';
import '../domain/institution_group_list_repository.dart';
import 'institution_group_list_remote_data_source.dart';

final institutionGroupListRepositoryProvider =
    Provider<InstitutionGroupListRepository>((ref) {
      return InstitutionGroupListRepositoryImpl(
        remoteDataSource: ref.watch(
          institutionGroupListRemoteDataSourceProvider,
        ),
      );
    });

class InstitutionGroupListRepositoryImpl
    implements InstitutionGroupListRepository {
  const InstitutionGroupListRepositoryImpl({required this.remoteDataSource});

  final InstitutionGroupListRemoteDataSource remoteDataSource;

  @override
  Future<InstitutionGroupListPage> fetchGroups(
    InstitutionGroupListQuery query,
  ) async {
    final dto = await remoteDataSource.fetchGroups(query);

    return dto.toDomain();
  }
}
