import 'teacher_topic.dart';
import 'teacher_topic_mutation.dart';

abstract interface class TeacherTopicRepository {
  Future<TeacherTopic> createTopic(TeacherTopicCreateRequest request);

  Future<TeacherTopic> fetchTopic(String topicId);

  Future<TeacherTopic> updateTopic(
    String topicId,
    TeacherTopicEditRequest request,
  );

  Future<TeacherTopic> performLifecycleAction(
    String topicId,
    TeacherTopicLifecycleAction action,
  );
}
