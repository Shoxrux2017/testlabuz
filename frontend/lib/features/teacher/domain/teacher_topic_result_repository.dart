import 'teacher_topic_result.dart';
import 'teacher_topic_result_list.dart';
import 'teacher_topic_result_mutation.dart';

abstract interface class TeacherTopicResultRepository {
  Future<TeacherTopicResultList> fetchResults(
    String topicId,
    TeacherTopicResultListQuery query,
  );

  Future<TeacherTopicResultDetail> fetchResult(
    String topicId,
    String studentId,
  );

  /// Saves [comment] trimmed; an empty text removes the comment.
  Future<TeacherTopicResultDetail> updateComment(
    String topicId,
    String studentId,
    String comment,
  );

  Future<TeacherTopicResultDetail> release(
    String topicId,
    String studentId,
    TeacherTopicResultAudience audience,
  );

  Future<TeacherTopicResultDetail> close(String topicId, String studentId);

  /// Releases every ready result of the Topic's cohort to [audience].
  Future<TeacherTopicResultBulkOutcome> releaseAll(
    String topicId,
    TeacherTopicResultAudience audience,
  );

  /// Closes every closable result of the Topic's cohort.
  Future<TeacherTopicResultBulkOutcome> closeAll(String topicId);
}
