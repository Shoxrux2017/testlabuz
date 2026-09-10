import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/student_homework_attempt.dart';
import '../domain/student_homework_attempt_repository.dart';
import 'student_homework_attempt_remote_data_source.dart';

final studentHomeworkAttemptRepositoryProvider =
    Provider<StudentHomeworkAttemptRepository>((ref) {
      return StudentHomeworkAttemptRepositoryImpl(
        remoteDataSource: ref.watch(
          studentHomeworkAttemptRemoteDataSourceProvider,
        ),
      );
    });

class StudentHomeworkAttemptRepositoryImpl
    implements StudentHomeworkAttemptRepository {
  const StudentHomeworkAttemptRepositoryImpl({required this.remoteDataSource});

  final StudentHomeworkAttemptRemoteDataSource remoteDataSource;

  @override
  Future<StudentHomeworkAttemptStartResult> startAttempt(
    String homeworkId,
    String idempotencyKey,
  ) async {
    return (await remoteDataSource.startAttempt(
      homeworkId,
      idempotencyKey,
    )).toDomain();
  }

  @override
  Future<StudentHomeworkAttempt> fetchAttempt(String attemptId) async {
    return (await remoteDataSource.fetchAttempt(attemptId)).toDomain();
  }
}
