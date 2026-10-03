import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../domain/teacher_topic_result.dart';
import '../domain/teacher_topic_result_list.dart';
import '../domain/teacher_topic_result_repository.dart';
import 'teacher_topic_result_remote_data_source.dart';

final teacherTopicResultRepositoryProvider =
    Provider<TeacherTopicResultRepository>((ref) {
      return TeacherTopicResultRepositoryImpl(
        remoteDataSource: ref.watch(teacherTopicResultRemoteDataSourceProvider),
      );
    });

class TeacherTopicResultRepositoryImpl implements TeacherTopicResultRepository {
  const TeacherTopicResultRepositoryImpl({required this.remoteDataSource});

  final TeacherTopicResultRemoteDataSource remoteDataSource;

  @override
  Future<TeacherTopicResultList> fetchResults(
    String topicId,
    TeacherTopicResultListQuery query,
  ) {
    return remoteDataSource.fetchResults(topicId, query);
  }

  @override
  Future<TeacherTopicResultDetail> fetchResult(
    String topicId,
    String studentId,
  ) async {
    final detail = await remoteDataSource.fetchResult(topicId, studentId);
    if (detail.result.studentId.toLowerCase() != studentId.toLowerCase()) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Teacher Topic result Student does not match the request.',
        ),
      );
    }
    return detail;
  }
}
