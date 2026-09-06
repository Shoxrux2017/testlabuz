import '../domain/teacher_homework.dart';
import '../domain/teacher_topic.dart';

class TeacherHomeworkRouteTarget {
  TeacherHomeworkRouteTarget({
    required this.topicId,
    required this.homeworkId,
  }) {
    if (!isCanonicalTeacherTopicId(topicId)) {
      throw ArgumentError.value(
        topicId,
        'topicId',
        'Topic ID must be a canonical UUID.',
      );
    }
    if (!isCanonicalTeacherHomeworkId(homeworkId)) {
      throw ArgumentError.value(
        homeworkId,
        'homeworkId',
        'Homework ID must be a canonical UUID.',
      );
    }
  }

  final String topicId;
  final String homeworkId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherHomeworkRouteTarget &&
            other.topicId.toLowerCase() == topicId.toLowerCase() &&
            other.homeworkId.toLowerCase() == homeworkId.toLowerCase();
  }

  @override
  int get hashCode =>
      Object.hash(topicId.toLowerCase(), homeworkId.toLowerCase());
}
