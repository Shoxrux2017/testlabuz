import 'teacher_topic_list.dart';
import 'teacher_topic_list_query.dart';

abstract interface class TeacherTopicListRepository {
  Future<TeacherTopicListPage> fetchTopics(TeacherTopicListQuery query);
}
