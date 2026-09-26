import 'student_blitz.dart';
import 'student_blitz_route_target.dart';

/// Owner identity of one Attempt's answer, file, transfer and Submit
/// controllers inside a Blitz route session. It is not a Flutter route.
class StudentBlitzExecutionTarget {
  factory StudentBlitzExecutionTarget({
    required StudentBlitzRouteTarget routeTarget,
    required String attemptId,
  }) {
    if (!isCanonicalStudentBlitzId(attemptId)) {
      throw ArgumentError.value(
        attemptId,
        'attemptId',
        'Expected an Attempt UUID.',
      );
    }
    return StudentBlitzExecutionTarget._(
      routeTarget: routeTarget,
      attemptId: attemptId.toLowerCase(),
    );
  }

  const StudentBlitzExecutionTarget._({
    required this.routeTarget,
    required this.attemptId,
  });

  final StudentBlitzRouteTarget routeTarget;
  final String attemptId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentBlitzExecutionTarget &&
          other.routeTarget.topicId == routeTarget.topicId &&
          other.routeTarget.blitzId == routeTarget.blitzId &&
          other.attemptId == attemptId;

  @override
  int get hashCode =>
      Object.hash(routeTarget.topicId, routeTarget.blitzId, attemptId);
}
