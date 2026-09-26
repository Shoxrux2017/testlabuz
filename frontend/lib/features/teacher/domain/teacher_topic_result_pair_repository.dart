import 'teacher_topic_result_pair.dart';

abstract interface class TeacherTopicResultPairRepository {
  Future<TeacherTopicResultPair?> fetchResultPair(String topicId);

  Future<TeacherTopicResultPair> setOfficialHomework(
    String topicId,
    String homeworkId,
  );

  /// Designates [blitzId] while preserving the current official Homework.
  Future<TeacherTopicResultPair> setOfficialBlitz(
    String topicId, {
    required String homeworkId,
    required String blitzId,
  });
}
