import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../domain/student_topic.dart';
import '../domain/student_topic_list.dart';
import '../domain/student_topic_list_query.dart';
import '../domain/student_topic_repository.dart';
import 'student_topic_remote_data_source.dart';

final studentTopicRepositoryProvider = Provider<StudentTopicRepository>((ref) {
  return StudentTopicRepositoryImpl(
    remoteDataSource: ref.watch(studentTopicRemoteDataSourceProvider),
  );
});

class StudentTopicRepositoryImpl implements StudentTopicRepository {
  const StudentTopicRepositoryImpl({required this.remoteDataSource});

  final StudentTopicRemoteDataSource remoteDataSource;

  @override
  Future<StudentTopicListPage> fetchTopics(StudentTopicListQuery query) async {
    final dto = await remoteDataSource.fetchTopics(query);
    return dto.toDomain();
  }

  @override
  Future<StudentTopicDetail> fetchTopic(String topicId) async {
    final dto = await remoteDataSource.fetchTopic(topicId);
    final topic = dto.toDomain();
    if (topic.id.toLowerCase() != topicId.toLowerCase()) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Student Topic detail ID does not match the request.',
        ),
      );
    }

    return topic;
  }
}
