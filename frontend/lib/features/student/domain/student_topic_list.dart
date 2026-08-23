import 'student_topic.dart';

class StudentListPagination {
  const StudentListPagination({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  final int page;
  final int perPage;
  final int total;
  final int lastPage;
}

class StudentTopicListPage {
  StudentTopicListPage({
    required List<StudentTopicSummary> topics,
    required this.pagination,
  }) : topics = List<StudentTopicSummary>.unmodifiable(topics);

  final List<StudentTopicSummary> topics;
  final StudentListPagination pagination;
}
