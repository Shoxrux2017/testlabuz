import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/student_answer_mutation.dart';
import '../domain/student_attempt_answer_repository.dart';
import '../domain/student_question.dart';
import '../domain/student_submission_upload.dart';
import 'student_attempt_answer_remote_data_source.dart';

final studentAttemptAnswerRepositoryProvider =
    Provider<StudentAttemptAnswerRepository>((ref) {
      return StudentAttemptAnswerRepositoryImpl(
        remoteDataSource: ref.watch(
          studentAttemptAnswerRemoteDataSourceProvider,
        ),
      );
    });

class StudentAttemptAnswerRepositoryImpl
    implements StudentAttemptAnswerRepository {
  const StudentAttemptAnswerRepositoryImpl({required this.remoteDataSource});

  final StudentAttemptAnswerRemoteDataSource remoteDataSource;

  @override
  Future<StudentAttemptAnswerMutationResult> saveAnswer(
    String attemptId,
    StudentQuestion question,
    StudentAnswerMutation mutation,
  ) async {
    return (await remoteDataSource.saveAnswer(
      attemptId,
      question,
      mutation,
    )).toDomain();
  }

  @override
  Future<StudentAttemptAnswerMutationResult> uploadFileAnswer(
    String attemptId,
    StudentQuestion question,
    StudentSubmissionUploadFile file, {
    StudentSubmissionUploadProgress? onProgress,
  }) async {
    return (await remoteDataSource.uploadFileAnswer(
      attemptId,
      question,
      file,
      onProgress: onProgress,
    )).toDomain();
  }
}
