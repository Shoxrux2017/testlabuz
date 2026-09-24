import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_list.dart';
import '../domain/teacher_blitz_list_query.dart';
import '../domain/teacher_blitz_repository.dart';
import 'teacher_blitz_remote_data_source.dart';

final teacherBlitzRepositoryProvider = Provider<TeacherBlitzRepository>((ref) {
  return TeacherBlitzRepositoryImpl(
    remoteDataSource: ref.watch(teacherBlitzRemoteDataSourceProvider),
  );
});

class TeacherBlitzRepositoryImpl implements TeacherBlitzRepository {
  const TeacherBlitzRepositoryImpl({required this.remoteDataSource});

  final TeacherBlitzRemoteDataSource remoteDataSource;

  @override
  Future<TeacherBlitzList> fetchBlitzList(
    String topicId,
    TeacherBlitzListQuery query,
  ) async {
    final dto = await remoteDataSource.fetchBlitzList(topicId, query);
    return dto.toDomain();
  }

  @override
  Future<TeacherBlitz> fetchBlitz(String blitzId) async {
    final dto = await remoteDataSource.fetchBlitz(blitzId);
    final blitz = dto.blitz.toDomain();
    if (blitz.id.toLowerCase() != blitzId.toLowerCase()) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Teacher Blitz detail ID does not match the request.',
        ),
      );
    }
    return blitz;
  }
}
