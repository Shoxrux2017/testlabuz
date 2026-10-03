import 'teacher_topic_result.dart';
import 'teacher_topic_result_list.dart';

abstract interface class TeacherTopicResultRepository {
  Future<TeacherTopicResultList> fetchResults(
    String topicId,
    TeacherTopicResultListQuery query,
  );

  Future<TeacherTopicResultDetail> fetchResult(
    String topicId,
    String studentId,
  );
}
