import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/student_homework.dart';
import '../domain/student_homework_list.dart';
import '../domain/student_homework_list_query.dart';
import '../domain/student_homework_repository.dart';
import 'student_homework_remote_data_source.dart';

final studentHomeworkRepositoryProvider = Provider<StudentHomeworkRepository>((
  ref,
) {
  return StudentHomeworkRepositoryImpl(
    remoteDataSource: ref.watch(studentHomeworkRemoteDataSourceProvider),
  );
});

class StudentHomeworkRepositoryImpl implements StudentHomeworkRepository {
  const StudentHomeworkRepositoryImpl({required this.remoteDataSource});

  final StudentHomeworkRemoteDataSource remoteDataSource;

  @override
  Future<StudentHomeworkList> fetchHomework(
    StudentHomeworkListQuery query,
  ) async {
    return (await remoteDataSource.fetchHomework(query)).toDomain();
  }

  @override
  Future<StudentHomeworkDetail> fetchHomeworkDetail(String homeworkId) async {
    return (await remoteDataSource.fetchHomeworkDetail(homeworkId)).toDomain();
  }
}
