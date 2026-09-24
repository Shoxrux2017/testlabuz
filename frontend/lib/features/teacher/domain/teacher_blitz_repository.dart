import 'teacher_blitz.dart';
import 'teacher_blitz_list.dart';
import 'teacher_blitz_list_query.dart';

abstract interface class TeacherBlitzRepository {
  Future<TeacherBlitzList> fetchBlitzList(
    String topicId,
    TeacherBlitzListQuery query,
  );

  Future<TeacherBlitz> fetchBlitz(String blitzId);
}
