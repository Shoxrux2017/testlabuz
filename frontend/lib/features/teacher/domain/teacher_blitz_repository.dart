import 'teacher_blitz.dart';
import 'teacher_blitz_list.dart';
import 'teacher_blitz_list_query.dart';
import 'teacher_blitz_mutation.dart';
import 'teacher_question_mutation.dart';

abstract interface class TeacherBlitzRepository {
  Future<TeacherBlitzList> fetchBlitzList(
    String topicId,
    TeacherBlitzListQuery query,
  );

  Future<TeacherBlitz> fetchBlitz(String blitzId);

  Future<TeacherBlitz> createBlitz(
    String topicId,
    TeacherBlitzCreateRequest request,
  );

  Future<TeacherBlitz> updateBlitz(
    String blitzId,
    TeacherBlitzEditRequest request,
  );

  Future<TeacherBlitz> addQuestion(
    String blitzId,
    TeacherQuestionCreateRequest request,
  );

  Future<TeacherBlitz> updateQuestion(
    String questionId,
    TeacherQuestionEditRequest request,
  );

  Future<TeacherBlitz> deleteQuestion(String questionId);

  Future<TeacherBlitz> reorderQuestions(
    String blitzId,
    TeacherQuestionReorderRequest request,
  );
}
