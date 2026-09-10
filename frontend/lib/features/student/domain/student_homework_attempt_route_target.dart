import 'student_homework.dart';
import 'student_homework_route_target.dart';

class StudentHomeworkAttemptRouteTarget {
  factory StudentHomeworkAttemptRouteTarget({
    required String topicId,
    required String homeworkId,
    required String attemptId,
  }) {
    final homeworkTarget = StudentHomeworkRouteTarget(
      topicId: topicId,
      homeworkId: homeworkId,
    );
    if (!isCanonicalStudentAttemptId(attemptId)) {
      throw ArgumentError.value(
        attemptId,
        'attemptId',
        'Expected an Attempt UUID.',
      );
    }
    return StudentHomeworkAttemptRouteTarget._(
      topicId: homeworkTarget.topicId,
      homeworkId: homeworkTarget.homeworkId,
      attemptId: attemptId.toLowerCase(),
    );
  }

  const StudentHomeworkAttemptRouteTarget._({
    required this.topicId,
    required this.homeworkId,
    required this.attemptId,
  });

  final String topicId;
  final String homeworkId;
  final String attemptId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentHomeworkAttemptRouteTarget &&
          other.topicId == topicId &&
          other.homeworkId == homeworkId &&
          other.attemptId == attemptId;

  @override
  int get hashCode => Object.hash(topicId, homeworkId, attemptId);
}
