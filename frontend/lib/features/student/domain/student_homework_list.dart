import 'student_homework.dart';

class StudentHomeworkList {
  StudentHomeworkList({
    required List<StudentHomeworkSummary> items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  }) : items = List<StudentHomeworkSummary>.unmodifiable(items);

  final List<StudentHomeworkSummary> items;
  final int page;
  final int perPage;
  final int total;
  final int lastPage;
}
