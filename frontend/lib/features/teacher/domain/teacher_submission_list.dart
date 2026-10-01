import 'teacher_list_pagination.dart';
import 'teacher_submission.dart';

class TeacherSubmissionList {
  TeacherSubmissionList({
    required List<TeacherSubmission> items,
    required this.pagination,
  }) : items = List<TeacherSubmission>.unmodifiable(items);

  final List<TeacherSubmission> items;
  final TeacherListPagination pagination;
}
