import 'student_topic.dart';
import 'student_topic_list.dart';
import 'student_topic_list_query.dart';

abstract interface class StudentTopicRepository {
  Future<StudentTopicListPage> fetchTopics(StudentTopicListQuery query);

  Future<StudentTopicDetail> fetchTopic(String topicId);
}
