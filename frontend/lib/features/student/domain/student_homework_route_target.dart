import 'student_homework.dart';
import 'student_topic.dart';

class StudentHomeworkRouteTarget {
  factory StudentHomeworkRouteTarget({
    required String topicId,
    required String homeworkId,
  }) {
    if (!isCanonicalStudentTopicId(topicId)) {
      throw ArgumentError.value(topicId, 'topicId', 'Expected a Topic UUID.');
    }
    if (!isCanonicalStudentHomeworkId(homeworkId)) {
      throw ArgumentError.value(
        homeworkId,
        'homeworkId',
        'Expected a Homework UUID.',
      );
    }
    return StudentHomeworkRouteTarget._(
      topicId: topicId.toLowerCase(),
      homeworkId: homeworkId.toLowerCase(),
    );
  }

  const StudentHomeworkRouteTarget._({
    required this.topicId,
    required this.homeworkId,
  });

  final String topicId;
  final String homeworkId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentHomeworkRouteTarget &&
          other.topicId == topicId &&
          other.homeworkId == homeworkId;

  @override
  int get hashCode => Object.hash(topicId, homeworkId);
}
