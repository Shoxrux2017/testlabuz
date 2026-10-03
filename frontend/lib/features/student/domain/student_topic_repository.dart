import 'student_topic.dart';
import 'student_topic_list.dart';
import 'student_topic_list_query.dart';
import 'student_topic_result.dart';

abstract interface class StudentTopicRepository {
  Future<StudentTopicListPage> fetchTopics(StudentTopicListQuery query);

  Future<StudentTopicDetail> fetchTopic(String topicId);

  /// The Student's own Topic result, or null when the Student has none.
  Future<StudentTopicResult?> fetchTopicResult(String topicId);
}
