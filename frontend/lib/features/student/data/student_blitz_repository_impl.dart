import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/student_blitz.dart';
import '../domain/student_blitz_repository.dart';
import '../domain/student_finished_blitz.dart';
import 'student_blitz_remote_data_source.dart';

final studentBlitzRepositoryProvider = Provider<StudentBlitzRepository>((ref) {
  return StudentBlitzRepositoryImpl(
    remoteDataSource: ref.watch(studentBlitzRemoteDataSourceProvider),
  );
});

class StudentBlitzRepositoryImpl implements StudentBlitzRepository {
  const StudentBlitzRepositoryImpl({required this.remoteDataSource});

  final StudentBlitzRemoteDataSource remoteDataSource;

  @override
  Future<List<StudentActiveBlitzSummary>> fetchActiveBlitz() async {
    return (await remoteDataSource.fetchActiveBlitz()).toDomain();
  }

  @override
  Future<StudentBlitzDetail> fetchBlitz(String blitzId) async {
    return (await remoteDataSource.fetchBlitz(blitzId)).toDomain();
  }

  @override
  Future<StudentFinishedBlitzPage> fetchFinishedBlitz({
    required int page,
    required int perPage,
  }) async {
    return (await remoteDataSource.fetchFinishedBlitz(
      page: page,
      perPage: perPage,
    )).toDomain();
  }
}
