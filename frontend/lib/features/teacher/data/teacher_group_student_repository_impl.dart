import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/teacher_group_student_list.dart';
import '../domain/teacher_group_student_list_query.dart';
import '../domain/teacher_group_student_repository.dart';
import 'teacher_group_student_remote_data_source.dart';

final teacherGroupStudentRepositoryProvider =
    Provider<TeacherGroupStudentRepository>((ref) {
      return TeacherGroupStudentRepositoryImpl(
        remoteDataSource: ref.watch(
          teacherGroupStudentRemoteDataSourceProvider,
        ),
      );
    });

class TeacherGroupStudentRepositoryImpl
    implements TeacherGroupStudentRepository {
  const TeacherGroupStudentRepositoryImpl({required this.remoteDataSource});

  final TeacherGroupStudentRemoteDataSource remoteDataSource;

  @override
  Future<TeacherGroupStudentList> fetchGroupStudents(
    String groupId,
    TeacherGroupStudentListQuery query,
  ) async {
    final dto = await remoteDataSource.fetchGroupStudents(groupId, query);
    return dto.toDomain();
  }
}
