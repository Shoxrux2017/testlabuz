import 'student_blitz.dart';
import 'student_topic.dart';

/// Route identity of `/student/topics/:topicId/blitz/:blitzId`; it never
/// carries an Attempt ID.
class StudentBlitzRouteTarget {
  factory StudentBlitzRouteTarget({
    required String topicId,
    required String blitzId,
  }) {
    if (!isCanonicalStudentTopicId(topicId)) {
      throw ArgumentError.value(topicId, 'topicId', 'Expected a Topic UUID.');
    }
    if (!isCanonicalStudentBlitzId(blitzId)) {
      throw ArgumentError.value(blitzId, 'blitzId', 'Expected a Blitz UUID.');
    }
    return StudentBlitzRouteTarget._(
      topicId: topicId.toLowerCase(),
      blitzId: blitzId.toLowerCase(),
    );
  }

  const StudentBlitzRouteTarget._({
    required this.topicId,
    required this.blitzId,
  });

  final String topicId;
  final String blitzId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentBlitzRouteTarget &&
          other.topicId == topicId &&
          other.blitzId == blitzId;

  @override
  int get hashCode => Object.hash(topicId, blitzId);
}
