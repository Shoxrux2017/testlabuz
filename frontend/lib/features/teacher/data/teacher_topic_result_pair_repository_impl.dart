import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../domain/teacher_topic_result_pair.dart';
import '../domain/teacher_topic_result_pair_repository.dart';
import 'teacher_topic_result_pair_remote_data_source.dart';

final teacherTopicResultPairRepositoryProvider =
    Provider<TeacherTopicResultPairRepository>((ref) {
      return TeacherTopicResultPairRepositoryImpl(
        remoteDataSource: ref.watch(
          teacherTopicResultPairRemoteDataSourceProvider,
        ),
      );
    });

class TeacherTopicResultPairRepositoryImpl
    implements TeacherTopicResultPairRepository {
  const TeacherTopicResultPairRepositoryImpl({required this.remoteDataSource});

  final TeacherTopicResultPairRemoteDataSource remoteDataSource;

  @override
  Future<TeacherTopicResultPair?> fetchResultPair(String topicId) async {
    final dto = await remoteDataSource.fetchResultPair(topicId);
    final pair = dto.pair?.toDomain();
    if (pair != null && pair.topicId.toLowerCase() != topicId.toLowerCase()) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message:
              'Teacher Topic result pair Topic does not match the request.',
        ),
      );
    }
    return pair;
  }

  @override
  Future<TeacherTopicResultPair> setOfficialHomework(
    String topicId,
    String homeworkId,
  ) async {
    final dto = await remoteDataSource.setOfficialHomework(topicId, homeworkId);
    final pair = dto.pair.toDomain();
    if (pair.topicId.toLowerCase() != topicId.toLowerCase() ||
        pair.homeworkAssessmentId.toLowerCase() != homeworkId.toLowerCase()) {
      throw const TeacherTopicResultPairMutationOutcomeUnknownException();
    }
    return pair;
  }
}
