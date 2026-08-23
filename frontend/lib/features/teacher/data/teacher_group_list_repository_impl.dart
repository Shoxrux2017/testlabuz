import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/teacher_group_list.dart';
import '../domain/teacher_group_list_query.dart';
import '../domain/teacher_group_list_repository.dart';
import 'teacher_group_list_remote_data_source.dart';

final teacherGroupListRepositoryProvider = Provider<TeacherGroupListRepository>(
  (ref) {
    return TeacherGroupListRepositoryImpl(
      remoteDataSource: ref.watch(teacherGroupListRemoteDataSourceProvider),
    );
  },
);

class TeacherGroupListRepositoryImpl implements TeacherGroupListRepository {
  const TeacherGroupListRepositoryImpl({required this.remoteDataSource});

  final TeacherGroupListRemoteDataSource remoteDataSource;

  @override
  Future<TeacherGroupListPage> fetchGroups(TeacherGroupListQuery query) async {
    final dto = await remoteDataSource.fetchGroups(query);

    return dto.toDomain();
  }
}
