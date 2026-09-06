import 'teacher_group_student_list.dart';
import 'teacher_group_student_list_query.dart';

abstract interface class TeacherGroupStudentRepository {
  Future<TeacherGroupStudentList> fetchGroupStudents(
    String groupId,
    TeacherGroupStudentListQuery query,
  );
}
