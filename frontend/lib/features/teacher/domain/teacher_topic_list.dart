import 'teacher_list_pagination.dart';
import 'teacher_topic.dart';

class TeacherTopicListPage {
  const TeacherTopicListPage({required this.topics, required this.pagination});

  final List<TeacherTopic> topics;
  final TeacherListPagination pagination;
}
