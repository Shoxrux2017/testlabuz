import 'student_homework.dart';
import 'student_homework_list.dart';
import 'student_homework_list_query.dart';

abstract interface class StudentHomeworkRepository {
  Future<StudentHomeworkList> fetchHomework(StudentHomeworkListQuery query);

  Future<StudentHomeworkDetail> fetchHomeworkDetail(String homeworkId);
}
