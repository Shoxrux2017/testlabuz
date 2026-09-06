import 'teacher_homework.dart';
import 'teacher_list_pagination.dart';

class TeacherHomeworkList {
  TeacherHomeworkList({
    required List<TeacherHomeworkSummary> items,
    required this.pagination,
  }) : items = List<TeacherHomeworkSummary>.unmodifiable(items);

  final List<TeacherHomeworkSummary> items;
  final TeacherListPagination pagination;
}
