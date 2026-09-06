import 'teacher_homework.dart';
import 'teacher_homework_lifecycle.dart';
import 'teacher_homework_list.dart';
import 'teacher_homework_list_query.dart';
import 'teacher_homework_mutation.dart';
import 'teacher_question_mutation.dart';

abstract interface class TeacherHomeworkRepository {
  Future<TeacherHomeworkList> fetchHomeworkList(
    String topicId,
    TeacherHomeworkListQuery query,
  );

  Future<TeacherHomework> fetchHomework(String homeworkId);

  Future<TeacherHomework> createHomework(
    String topicId,
    TeacherHomeworkCreateRequest request,
  );

  Future<TeacherHomework> updateHomework(
    String homeworkId,
    TeacherHomeworkEditRequest request,
  );

  Future<TeacherHomework> performLifecycleAction(
    String homeworkId,
    TeacherHomeworkLifecycleAction action,
  );

  Future<TeacherHomework> addQuestion(
    String homeworkId,
    TeacherQuestionCreateRequest request,
  );

  Future<TeacherHomework> updateQuestion(
    String questionId,
    TeacherQuestionEditRequest request,
  );

  Future<TeacherHomework> deleteQuestion(String questionId);

  Future<TeacherHomework> reorderQuestions(
    String homeworkId,
    TeacherQuestionReorderRequest request,
  );
}
