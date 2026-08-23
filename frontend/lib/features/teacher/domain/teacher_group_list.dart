import 'teacher_group.dart';
import 'teacher_list_pagination.dart';

class TeacherGroupListPage {
  const TeacherGroupListPage({required this.groups, required this.pagination});

  final List<TeacherGroupSummary> groups;
  final TeacherListPagination pagination;
}
