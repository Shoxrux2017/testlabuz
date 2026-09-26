import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/student_blitz_attempt.dart';
import '../domain/student_blitz_attempt_repository.dart';
import 'student_blitz_attempt_remote_data_source.dart';

final studentBlitzAttemptRepositoryProvider =
    Provider<StudentBlitzAttemptRepository>((ref) {
      return StudentBlitzAttemptRepositoryImpl(
        remoteDataSource: ref.watch(
          studentBlitzAttemptRemoteDataSourceProvider,
        ),
      );
    });

class StudentBlitzAttemptRepositoryImpl
    implements StudentBlitzAttemptRepository {
  const StudentBlitzAttemptRepositoryImpl({required this.remoteDataSource});

  final StudentBlitzAttemptRemoteDataSource remoteDataSource;

  @override
  Future<StudentBlitzAttemptStartResult> start(
    String blitzId,
    StudentBlitzAttemptRequest request,
  ) async {
    return (await remoteDataSource.start(blitzId, request)).toDomain();
  }
}
