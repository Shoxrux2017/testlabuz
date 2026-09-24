import '../domain/teacher_blitz.dart';
import '../domain/teacher_topic.dart';
import 'teacher_question_authoring_route_target.dart';

class TeacherBlitzRouteTarget implements TeacherQuestionAuthoringRouteTarget {
  TeacherBlitzRouteTarget({required this.topicId, required this.blitzId}) {
    if (!isCanonicalTeacherTopicId(topicId)) {
      throw ArgumentError.value(
        topicId,
        'topicId',
        'Topic ID must be a canonical UUID.',
      );
    }
    if (!isCanonicalTeacherBlitzId(blitzId)) {
      throw ArgumentError.value(
        blitzId,
        'blitzId',
        'Blitz ID must be a canonical UUID.',
      );
    }
  }

  @override
  final String topicId;
  final String blitzId;

  @override
  String get assessmentId => blitzId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherBlitzRouteTarget &&
            other.topicId.toLowerCase() == topicId.toLowerCase() &&
            other.blitzId.toLowerCase() == blitzId.toLowerCase();
  }

  @override
  int get hashCode => Object.hash(topicId.toLowerCase(), blitzId.toLowerCase());
}
