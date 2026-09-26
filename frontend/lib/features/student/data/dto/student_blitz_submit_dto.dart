import '../../domain/student_blitz_attempt.dart';
import '../../domain/student_blitz_submit.dart';
import 'student_blitz_attempt_dto.dart';
import 'student_dto_parse.dart';

class StudentBlitzSubmitDto {
  const StudentBlitzSubmitDto._(this.attempt);

  /// Strict Submit success for [expectedAttemptId] of [expectedBlitzId].
  ///
  /// Every accepted Attempt has the original Student Submit lineage; a
  /// timeout or Teacher-close finalization is never a Submit success.
  factory StudentBlitzSubmitDto.fromJson(
    Object? json, {
    required String expectedAttemptId,
    required String expectedBlitzId,
    required StudentBlitzSubmitResponseExpectation expectation,
  }) {
    readStudentCanonicalUuid({'id': expectedAttemptId}, 'id');
    readStudentCanonicalUuid({'id': expectedBlitzId}, 'id');
    final envelope = readExactStudentMap(
      json,
      context: 'Student Blitz Submit envelope',
      keys: const {'data', 'message'},
    );
    if (envelope['message'] != 'Blitz attempt submitted successfully.') {
      throw const FormatException('Student Blitz Submit message is invalid.');
    }
    final attempt = StudentBlitzAttemptDto.fromJson(
      envelope['data'],
    ).toDomain();
    if (attempt.id.toLowerCase() != expectedAttemptId.toLowerCase() ||
        attempt.assessmentId.toLowerCase() != expectedBlitzId.toLowerCase()) {
      throw const FormatException(
        'Student Blitz Submit response does not match its target.',
      );
    }
    final submittedAt = attempt.submittedAt;
    final finalizedAt = attempt.finalizedAt;
    if (attempt.finalizationReason !=
            StudentBlitzAttemptFinalizationReason.studentSubmit ||
        submittedAt == null ||
        finalizedAt == null ||
        !finalizedAt.isAtSameMomentAs(submittedAt) ||
        !finalizedAt.isBefore(attempt.deadlineAt) ||
        attempt.timing.remainingSeconds != 0) {
      throw const FormatException(
        'Student Blitz Submit response must confirm a Student Submit.',
      );
    }
    final statusAccepted = switch (expectation) {
      StudentBlitzSubmitResponseExpectation.fresh =>
        attempt.status == StudentBlitzAttemptStatus.submitted,
      StudentBlitzSubmitResponseExpectation.completedReplay =>
        attempt.status == StudentBlitzAttemptStatus.submitted ||
            attempt.status == StudentBlitzAttemptStatus.waitingForReview ||
            attempt.status == StudentBlitzAttemptStatus.checked,
    };
    if (!statusAccepted) {
      throw const FormatException(
        'Student Blitz Submit status does not match its expected response.',
      );
    }
    return StudentBlitzSubmitDto._(attempt);
  }

  final StudentBlitzAttempt attempt;

  StudentBlitzSubmitResult toDomain() =>
      StudentBlitzSubmitResult(attempt: attempt);
}
