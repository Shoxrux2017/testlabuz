import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_mutation.dart';
import '../domain/teacher_topic_repository.dart';
import 'teacher_topic_remote_data_source.dart';

final teacherTopicRepositoryProvider = Provider<TeacherTopicRepository>((ref) {
  return TeacherTopicRepositoryImpl(
    remoteDataSource: ref.watch(teacherTopicRemoteDataSourceProvider),
  );
});

class TeacherTopicRepositoryImpl implements TeacherTopicRepository {
  const TeacherTopicRepositoryImpl({required this.remoteDataSource});

  final TeacherTopicRemoteDataSource remoteDataSource;

  @override
  Future<TeacherTopic> createTopic(TeacherTopicCreateRequest request) async {
    final dto = await remoteDataSource.createTopic(request);
    final topic = dto.topic.toDomain();
    if (!request.matches(topic)) {
      throw const TeacherTopicMutationOutcomeUnknownException();
    }

    return topic;
  }

  @override
  Future<TeacherTopic> fetchTopic(String topicId) async {
    final dto = await remoteDataSource.fetchTopic(topicId);
    final topic = dto.topic.toDomain();
    if (topic.id.toLowerCase() != topicId.toLowerCase()) {
      throw ApiRequestException(
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Teacher Topic detail ID does not match the request.',
        ),
      );
    }

    return topic;
  }

  @override
  Future<TeacherTopic> updateTopic(
    String topicId,
    TeacherTopicEditRequest request,
  ) async {
    final dto = await remoteDataSource.updateTopic(topicId, request);
    final topic = dto.topic.toDomain();
    if (topic.id.toLowerCase() != topicId.toLowerCase() ||
        !request.matches(topic)) {
      throw const TeacherTopicMutationOutcomeUnknownException();
    }

    return topic;
  }

  @override
  Future<TeacherTopic> performLifecycleAction(
    String topicId,
    TeacherTopicLifecycleAction action,
  ) async {
    final dto = await remoteDataSource.performLifecycleAction(topicId, action);
    final topic = dto.topic.toDomain();
    if (topic.id.toLowerCase() != topicId.toLowerCase() ||
        topic.status != action.expectedStatus) {
      throw const TeacherTopicMutationOutcomeUnknownException();
    }

    return topic;
  }
}
