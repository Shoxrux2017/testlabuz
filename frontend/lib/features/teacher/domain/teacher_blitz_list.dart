import 'teacher_blitz.dart';
import 'teacher_list_pagination.dart';

class TeacherBlitzList {
  TeacherBlitzList({
    required List<TeacherBlitzSummary> items,
    required this.pagination,
  }) : items = List<TeacherBlitzSummary>.unmodifiable(items);

  final List<TeacherBlitzSummary> items;
  final TeacherListPagination pagination;
}
