import 'teacher_homework.dart';
import 'teacher_homework_list.dart';
import 'teacher_homework_list_query.dart';

abstract interface class TeacherHomeworkRepository {
  Future<TeacherHomeworkList> fetchHomeworkList(
    String topicId,
    TeacherHomeworkListQuery query,
  );

  Future<TeacherHomework> fetchHomework(String homeworkId);
}
