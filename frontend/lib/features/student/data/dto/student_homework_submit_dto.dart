import '../../domain/student_homework_attempt.dart';
import '../../domain/student_homework_submit.dart';
import 'student_dto_parse.dart';
import 'student_homework_attempt_dto.dart';

class StudentHomeworkSubmitDto {
  const StudentHomeworkSubmitDto({required this.attempt});

  factory StudentHomeworkSubmitDto.fromJson(
    Object? json, {
    required String expectedAttemptId,
    required String expectedHomeworkId,
  }) {
    if (expectedAttemptId.length != 36 || expectedHomeworkId.length != 36) {
      throw const FormatException(
        'Student Homework Submit target UUID is invalid.',
      );
    }
    readStudentCanonicalUuid({'id': expectedAttemptId}, 'id');
    readStudentCanonicalUuid({'id': expectedHomeworkId}, 'id');
    final envelope = readExactStudentMap(
      json,
      context: 'Student Homework Submit envelope',
      keys: const {'data', 'message'},
    );
    if (envelope['message'] != 'Homework submitted successfully.') {
      throw const FormatException(
        'Student Homework Submit message is invalid.',
      );
    }
    final attempt = StudentHomeworkAttemptDto.fromJson(envelope['data']);
    if (attempt.id.toLowerCase() != expectedAttemptId.toLowerCase() ||
        attempt.assessmentId.toLowerCase() !=
            expectedHomeworkId.toLowerCase()) {
      throw const FormatException(
        'Student Homework Submit response does not match its target.',
      );
    }
    if (attempt.status == StudentHomeworkAttemptStatus.inProgress ||
        attempt.finalizationReason !=
            StudentHomeworkAttemptFinalizationReason.studentSubmit ||
        attempt.submittedAt == null ||
        attempt.finalizedAt != attempt.submittedAt) {
      throw const FormatException(
        'Student Homework Submit response must confirm explicit submission.',
      );
    }
    return StudentHomeworkSubmitDto(attempt: attempt);
  }

  final StudentHomeworkAttemptDto attempt;

  StudentHomeworkSubmitResult toDomain() =>
      StudentHomeworkSubmitResult(attempt: attempt.toDomain());
}
