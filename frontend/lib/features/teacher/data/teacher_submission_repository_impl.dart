import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/teacher_submission_list.dart';
import '../domain/teacher_submission_list_query.dart';
import '../domain/teacher_submission_repository.dart';
import 'teacher_submission_remote_data_source.dart';

final teacherSubmissionRepositoryProvider =
    Provider<TeacherSubmissionRepository>((ref) {
      return TeacherSubmissionRepositoryImpl(
        remoteDataSource: ref.watch(teacherSubmissionRemoteDataSourceProvider),
      );
    });

class TeacherSubmissionRepositoryImpl implements TeacherSubmissionRepository {
  const TeacherSubmissionRepositoryImpl({required this.remoteDataSource});

  final TeacherSubmissionRemoteDataSource remoteDataSource;

  @override
  Future<TeacherSubmissionList> fetchSubmissions(
    TeacherSubmissionListQuery query,
  ) async {
    final dto = await remoteDataSource.fetchSubmissions(query);
    return dto.toDomain();
  }
}
