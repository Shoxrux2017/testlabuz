import '../../domain/student_blitz.dart';
import '../../domain/student_blitz_attempt.dart';
import 'student_attempt_answer_parser.dart';
import 'student_dto_parse.dart';

class StudentBlitzAttemptDto {
  const StudentBlitzAttemptDto._(this.attempt);

  /// Exact Attempt resource returned only by a Start/Resume POST.
  factory StudentBlitzAttemptDto.fromJson(Object? json) {
    final map = readExactStudentMap(
      json,
      context: 'Student Blitz Attempt',
      keys: const {
        'id',
        'assessment_id',
        'attempt_number',
        'status',
        'started_at',
        'deadline_at',
        'submitted_at',
        'finalized_at',
        'finalization_reason',
        'timing',
        'questions',
        'answers',
      },
    );
    final attemptNumber = readStudentInt(map, 'attempt_number');
    if (attemptNumber != 1 && attemptNumber != 2) {
      throw const FormatException('Blitz Attempt number must be 1 or 2.');
    }
    final status = StudentBlitzAttemptStatus.parse(
      readStudentNonBlankString(map, 'status'),
    );
    final reason = map['finalization_reason'] == null
        ? null
        : StudentBlitzAttemptFinalizationReason.parse(
            readStudentNonBlankString(map, 'finalization_reason'),
          );
    final startedAt = readStudentWholeSecondUtcTimestamp(map, 'started_at');
    final deadlineAt = readStudentWholeSecondUtcTimestamp(map, 'deadline_at');
    final submittedAt = readStudentNullableWholeSecondUtcTimestamp(
      map,
      'submitted_at',
    );
    final finalizedAt = readStudentNullableWholeSecondUtcTimestamp(
      map,
      'finalized_at',
    );
    final timing = _readTiming(map['timing']);
    _validateLifecycle(
      status: status,
      reason: reason,
      startedAt: startedAt,
      deadlineAt: deadlineAt,
      submittedAt: submittedAt,
      finalizedAt: finalizedAt,
      timing: timing,
    );
    final content = StudentAttemptContentDto.fromAttemptMap(map);
    return StudentBlitzAttemptDto._(
      StudentBlitzAttempt(
        id: readStudentCanonicalUuid(map, 'id'),
        assessmentId: readStudentCanonicalUuid(map, 'assessment_id'),
        attemptNumber: attemptNumber,
        status: status,
        startedAt: startedAt,
        deadlineAt: deadlineAt,
        submittedAt: submittedAt,
        finalizedAt: finalizedAt,
        finalizationReason: reason,
        timing: timing,
        questions: content.questions
            .map((question) => question.toDomain())
            .toList(),
        answers: content.answers,
      ),
    );
  }

  final StudentBlitzAttempt attempt;

  StudentBlitzAttempt toDomain() => attempt;
}

class StudentBlitzAttemptStartOperationDto {
  const StudentBlitzAttemptStartOperationDto._(this.result);

  /// Strict `201 started` / `200 resumed` success. The result kind comes from
  /// the HTTP status only; any other status/message pair is not success.
  factory StudentBlitzAttemptStartOperationDto.fromResponse({
    required int? statusCode,
    required Object? body,
  }) {
    final (kind, message) = switch (statusCode) {
      201 => (
        StudentBlitzAttemptStartResultKind.created,
        'Blitz attempt started successfully.',
      ),
      200 => (
        StudentBlitzAttemptStartResultKind.resumed,
        'Blitz attempt resumed successfully.',
      ),
      _ => throw const FormatException(
        'Blitz Attempt Start success status must be 200 or 201.',
      ),
    };
    final envelope = readExactStudentMap(
      body,
      context: 'Student Blitz Attempt Start envelope',
      keys: const {'data', 'message'},
    );
    if (envelope['message'] != message) {
      throw const FormatException(
        'Blitz Attempt Start message does not match its status.',
      );
    }
    return StudentBlitzAttemptStartOperationDto._(
      StudentBlitzAttemptStartResult(
        attempt: StudentBlitzAttemptDto.fromJson(envelope['data']).toDomain(),
        resultKind: kind,
      ),
    );
  }

  final StudentBlitzAttemptStartResult result;

  StudentBlitzAttemptStartResult toDomain() => result;
}

StudentBlitzAttemptTiming _readTiming(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student Blitz Attempt timing',
    keys: const {'server_now', 'mode', 'remaining_seconds'},
  );
  final remaining = readStudentInt(map, 'remaining_seconds');
  if (remaining < 0) {
    throw const FormatException('remaining_seconds must be non-negative.');
  }
  return StudentBlitzAttemptTiming(
    serverNow: readStudentWholeSecondUtcTimestamp(map, 'server_now'),
    mode: StudentBlitzTimerMode.parse(readStudentNonBlankString(map, 'mode')),
    remainingSeconds: remaining,
  );
}

void _validateLifecycle({
  required StudentBlitzAttemptStatus status,
  required StudentBlitzAttemptFinalizationReason? reason,
  required DateTime startedAt,
  required DateTime deadlineAt,
  required DateTime? submittedAt,
  required DateTime? finalizedAt,
  required StudentBlitzAttemptTiming timing,
}) {
  if (!deadlineAt.isAfter(startedAt)) {
    throw const FormatException('Blitz Attempt deadline must follow start.');
  }
  if (status == StudentBlitzAttemptStatus.inProgress) {
    final expected =
        deadlineAt.millisecondsSinceEpoch ~/ 1000 -
        timing.serverNow.millisecondsSinceEpoch ~/ 1000;
    if (submittedAt != null ||
        finalizedAt != null ||
        reason != null ||
        timing.remainingSeconds != (expected < 0 ? 0 : expected)) {
      throw const FormatException('In-progress Blitz Attempt is inconsistent.');
    }
    return;
  }
  if (finalizedAt == null ||
      reason == null ||
      finalizedAt.isBefore(startedAt) ||
      timing.remainingSeconds != 0) {
    throw const FormatException(
      'Terminal Blitz Attempt requires finalization.',
    );
  }
  final statusMatches = switch (status) {
    StudentBlitzAttemptStatus.submitted =>
      reason != StudentBlitzAttemptFinalizationReason.timeout,
    StudentBlitzAttemptStatus.timedOutFinalized =>
      reason == StudentBlitzAttemptFinalizationReason.timeout,
    _ => true,
  };
  // At or after the deadline the timeout reason always wins.
  final timestampsMatch = switch (reason) {
    StudentBlitzAttemptFinalizationReason.studentSubmit =>
      submittedAt != null &&
          submittedAt.isAtSameMomentAs(finalizedAt) &&
          finalizedAt.isBefore(deadlineAt),
    StudentBlitzAttemptFinalizationReason.timeout =>
      submittedAt == null && finalizedAt.isAtSameMomentAs(deadlineAt),
    StudentBlitzAttemptFinalizationReason.taskClosed =>
      submittedAt == null && finalizedAt.isBefore(deadlineAt),
  };
  if (!statusMatches || !timestampsMatch) {
    throw const FormatException(
      'Blitz Attempt finalization metadata is inconsistent.',
    );
  }
}
