import '../../domain/teacher_review_summary.dart';
import 'teacher_dto_parse.dart';

class TeacherReviewSummaryDto {
  const TeacherReviewSummaryDto({
    required this.waitingForTeacherReview,
    required this.overdue,
  });

  factory TeacherReviewSummaryDto.fromJson(
    Object? json, {
    required bool allowsOverdue,
  }) {
    final map = readExactTeacherMap(
      json,
      context: 'Teacher review summary',
      keys: const {'waiting_for_teacher_review', 'overdue'},
    );
    final waiting = readTeacherInt(map, 'waiting_for_teacher_review');
    final overdue = readTeacherInt(map, 'overdue');
    if (waiting < 0 ||
        overdue < 0 ||
        overdue > waiting ||
        (!allowsOverdue && overdue != 0)) {
      throw const FormatException('Teacher review summary is not consistent.');
    }

    return TeacherReviewSummaryDto(
      waitingForTeacherReview: waiting,
      overdue: overdue,
    );
  }

  final int waitingForTeacherReview;
  final int overdue;

  TeacherReviewSummary toDomain() {
    return TeacherReviewSummary(
      waitingForTeacherReview: waitingForTeacherReview,
      overdue: overdue,
    );
  }
}
