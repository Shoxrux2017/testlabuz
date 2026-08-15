import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/institution_user_list.dart';
import '../domain/institution_user_list_query.dart';
import '../domain/institution_user_list_repository.dart';
import 'institution_user_list_remote_data_source.dart';

final institutionUserListRepositoryProvider =
    Provider<InstitutionUserListRepository>((ref) {
      return InstitutionUserListRepositoryImpl(
        remoteDataSource: ref.watch(
          institutionUserListRemoteDataSourceProvider,
        ),
      );
    });

class InstitutionUserListRepositoryImpl
    implements InstitutionUserListRepository {
  const InstitutionUserListRepositoryImpl({required this.remoteDataSource});

  final InstitutionUserListRemoteDataSource remoteDataSource;

  @override
  Future<InstitutionUserListPage> fetchUsers(
    InstitutionUserListQuery query,
  ) async {
    final dto = await remoteDataSource.fetchUsers(query);

    return dto.toDomain();
  }
}
