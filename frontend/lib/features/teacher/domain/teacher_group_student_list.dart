import 'teacher_group_student.dart';
import 'teacher_list_pagination.dart';

class TeacherGroupStudentList {
  TeacherGroupStudentList({
    required List<TeacherGroupStudent> items,
    required this.pagination,
  }) : items = List<TeacherGroupStudent>.unmodifiable(items);

  final List<TeacherGroupStudent> items;
  final TeacherListPagination pagination;
}
