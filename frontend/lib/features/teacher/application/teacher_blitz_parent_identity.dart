import 'teacher_blitz_detail_state.dart';
import 'teacher_blitz_route_target.dart';

/// Whether the Blitz detail proves that the route Blitz belongs to the route
/// Topic. Nested routing proves nothing; only this confirmation may unlock
/// monitoring reads and grants.
enum TeacherBlitzParentIdentity { checking, confirmed, notFound, error }

TeacherBlitzParentIdentity teacherBlitzParentIdentity(
  TeacherBlitzDetailState detail,
  TeacherBlitzRouteTarget target,
) {
  switch (detail.status) {
    case TeacherBlitzDetailStatus.initial || TeacherBlitzDetailStatus.loading:
      return TeacherBlitzParentIdentity.checking;
    case TeacherBlitzDetailStatus.notFound:
      return TeacherBlitzParentIdentity.notFound;
    // A transport failure is not proof of a relationship mismatch.
    case TeacherBlitzDetailStatus.error:
      return TeacherBlitzParentIdentity.error;
    case TeacherBlitzDetailStatus.data || TeacherBlitzDetailStatus.refreshing:
      final blitz = detail.blitz;
      if (blitz == null) {
        return TeacherBlitzParentIdentity.checking;
      }
      return blitz.id.toLowerCase() == target.blitzId.toLowerCase() &&
              blitz.topicId.toLowerCase() == target.topicId.toLowerCase()
          ? TeacherBlitzParentIdentity.confirmed
          : TeacherBlitzParentIdentity.notFound;
  }
}
