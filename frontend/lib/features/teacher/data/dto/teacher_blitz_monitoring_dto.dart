import '../../domain/teacher_blitz.dart';
import '../../domain/teacher_blitz_attempt_exception.dart';
import '../../domain/teacher_blitz_monitoring.dart';
import 'teacher_blitz_attempt_exception_dto.dart';
import 'teacher_dto_parse.dart';

class TeacherBlitzMonitoringDto {
  const TeacherBlitzMonitoringDto._(this.monitoring);

  /// Strict Active-Blitz monitoring snapshot. Every row, the summary and the
  /// exception graph must agree; the always-null `score` is validated and
  /// discarded.
  factory TeacherBlitzMonitoringDto.fromJson(Object? json) {
    final envelope = readExactTeacherMap(
      json,
      context: 'Blitz monitoring envelope',
      keys: const {'data'},
    );
    final data = readExactTeacherMap(
      envelope['data'],
      context: 'Blitz monitoring',
      keys: const {'blitz', 'summary', 'students'},
    );
    final blitz = _readBlitz(data['blitz']);
    final summary = _readSummary(data['summary']);
    final rawStudents = data['students'];
    if (rawStudents is! List) {
      throw const FormatException('students must be a list.');
    }
    final students = [
      for (final row in rawStudents) _readStudent(row, blitz.timing.mode),
    ];
    _validateRoster(summary, students);
    return TeacherBlitzMonitoringDto._(
      TeacherBlitzMonitoring(
        blitz: blitz,
        summary: summary,
        students: students,
      ),
    );
  }

  final TeacherBlitzMonitoring monitoring;

  TeacherBlitzMonitoring toDomain() => monitoring;
}

TeacherBlitzMonitoringBlitz _readBlitz(Object? json) {
  final map = readExactTeacherMap(
    json,
    context: 'Blitz monitoring Blitz',
    keys: const {'id', 'status', 'duration_seconds', 'activated_at', 'timing'},
  );
  final status = TeacherBlitzStatus.parse(
    readTeacherNonBlankString(map, 'status'),
  );
  if (status != TeacherBlitzStatus.active) {
    throw const FormatException('Blitz monitoring requires an Active Blitz.');
  }
  final duration = readTeacherInt(map, 'duration_seconds');
  if (duration < 1) {
    throw const FormatException('duration_seconds must be positive.');
  }
  final timing = readExactTeacherMap(
    map['timing'],
    context: 'Blitz monitoring timing',
    keys: const {'mode', 'synchronized_ends_at', 'server_now'},
  );
  final mode = TeacherBlitzTimerStartMode.parse(
    readTeacherNonBlankString(timing, 'mode'),
  );
  final endsAt = readTeacherNullableWholeSecondUtcTimestamp(
    timing,
    'synchronized_ends_at',
  );
  if ((mode == TeacherBlitzTimerStartMode.synchronized) != (endsAt != null)) {
    throw const FormatException('Only a synchronized Blitz has a common end.');
  }
  return TeacherBlitzMonitoringBlitz(
    id: readTeacherCanonicalUuid(map, 'id'),
    status: status,
    durationSeconds: duration,
    activatedAt: readTeacherWholeSecondUtcTimestamp(map, 'activated_at'),
    timing: TeacherBlitzMonitoringTiming(
      mode: mode,
      synchronizedEndsAt: endsAt,
      serverNow: readTeacherWholeSecondUtcTimestamp(timing, 'server_now'),
    ),
  );
}

TeacherBlitzMonitoringSummary _readSummary(Object? json) {
  final map = readExactTeacherMap(
    json,
    context: 'Blitz monitoring summary',
    keys: const {
      'assigned',
      'not_started',
      'in_progress',
      'finalized',
      'waiting_for_teacher_review',
      'attempt_exceptions_granted',
    },
  );
  int count(String key) {
    final value = readTeacherInt(map, key);
    if (value < 0) {
      throw FormatException('$key must not be negative.');
    }
    return value;
  }

  final summary = TeacherBlitzMonitoringSummary(
    assigned: count('assigned'),
    notStarted: count('not_started'),
    inProgress: count('in_progress'),
    finalized: count('finalized'),
    waitingForTeacherReview: count('waiting_for_teacher_review'),
    attemptExceptionsGranted: count('attempt_exceptions_granted'),
  );
  if (summary.assigned !=
      summary.notStarted +
          summary.inProgress +
          summary.finalized +
          summary.waitingForTeacherReview) {
    throw const FormatException('Blitz monitoring summary is inconsistent.');
  }
  return summary;
}

TeacherBlitzMonitoringStudent _readStudent(
  Object? json,
  TeacherBlitzTimerStartMode mode,
) {
  final map = readExactTeacherMap(
    json,
    context: 'Blitz monitoring Student',
    keys: const {
      'student',
      'status',
      'attempt_number',
      'started_at',
      'deadline_at',
      'remaining_seconds',
      'finalization_reason',
      'score',
      'attempt_exception',
    },
  );
  // Stage 8 has no score; any value would be a leak, never data to show.
  if (map['score'] != null) {
    throw const FormatException('Stage 8 monitoring score must be null.');
  }
  final identity = readExactTeacherMap(
    map['student'],
    context: 'Blitz monitoring Student identity',
    keys: const {'id', 'full_name'},
  );
  final status = TeacherBlitzMonitoringStudentStatus.parse(
    readTeacherNonBlankString(map, 'status'),
  );
  final attemptNumber = map['attempt_number'] == null
      ? null
      : readTeacherInt(map, 'attempt_number');
  final startedAt = readTeacherNullableWholeSecondUtcTimestamp(
    map,
    'started_at',
  );
  final deadlineAt = readTeacherNullableWholeSecondUtcTimestamp(
    map,
    'deadline_at',
  );
  final remaining = map['remaining_seconds'] == null
      ? null
      : readTeacherInt(map, 'remaining_seconds');
  final reasonValue = readTeacherNullableString(map, 'finalization_reason');
  final reason = reasonValue == null
      ? null
      : TeacherBlitzMonitoringFinalizationReason.parse(reasonValue);
  final exception = map['attempt_exception'] == null
      ? null
      : _readException(map['attempt_exception']);
  final row = TeacherBlitzMonitoringStudent(
    student: TeacherBlitzMonitoringStudentIdentity(
      id: readTeacherCanonicalUuid(identity, 'id'),
      fullName: readTeacherNonBlankString(identity, 'full_name'),
    ),
    status: status,
    attemptNumber: attemptNumber,
    startedAt: startedAt,
    deadlineAt: deadlineAt,
    remainingSeconds: remaining,
    finalizationReason: reason,
    attemptException: exception,
  );
  _validateRow(row, mode);
  return row;
}

TeacherBlitzMonitoringAttemptException _readException(Object? json) {
  final map = readExactTeacherMap(
    json,
    context: 'Blitz monitoring attempt exception',
    keys: const {
      'id',
      'invalidated_attempt_id',
      'replacement_attempt_id',
      'reason_type',
      'reason',
      'granted_at',
      'replacement_attempt_available',
    },
  );
  final replacementAttemptId = readTeacherNullableCanonicalUuid(
    map,
    'replacement_attempt_id',
  );
  final available = readTeacherBool(map, 'replacement_attempt_available');
  // Monitoring is Active-only: an unused replacement is always available and
  // a started one never is.
  if ((replacementAttemptId == null) != available) {
    throw const FormatException(
      'Active monitoring exception availability is inconsistent.',
    );
  }
  return TeacherBlitzMonitoringAttemptException(
    id: readTeacherCanonicalUuid(map, 'id'),
    invalidatedAttemptId: readTeacherCanonicalUuid(
      map,
      'invalidated_attempt_id',
    ),
    replacementAttemptId: replacementAttemptId,
    reasonType: TeacherBlitzAttemptExceptionReasonType.parse(
      readTeacherNonBlankString(map, 'reason_type'),
    ),
    reason: readTeacherBlitzAttemptExceptionReason(map, 'reason'),
    grantedAt: readTeacherWholeSecondUtcTimestamp(map, 'granted_at'),
    replacementAttemptAvailable: available,
  );
}

void _validateRow(
  TeacherBlitzMonitoringStudent row,
  TeacherBlitzTimerStartMode mode,
) {
  final exception = row.attemptException;
  final valid = switch (row.status) {
    TeacherBlitzMonitoringStudentStatus.notStarted =>
      row.attemptNumber == null &&
          row.startedAt == null &&
          row.deadlineAt == null &&
          row.finalizationReason == null &&
          (row.remainingSeconds == null || row.remainingSeconds! >= 0) &&
          // Only the common class timer runs before an individual start.
          (mode == TeacherBlitzTimerStartMode.synchronized ||
              row.remainingSeconds == null) &&
          // An unused replacement has no current Attempt and no class time.
          (exception == null ||
              (exception.replacementAttemptAvailable &&
                  row.remainingSeconds == null)),
    TeacherBlitzMonitoringStudentStatus.inProgress =>
      _hasAttemptTimes(row) &&
          row.remainingSeconds != null &&
          row.remainingSeconds! >= 0 &&
          row.finalizationReason == null,
    TeacherBlitzMonitoringStudentStatus.finalized ||
    TeacherBlitzMonitoringStudentStatus.waitingForTeacherReview =>
      _hasAttemptTimes(row) &&
          row.remainingSeconds == 0 &&
          row.finalizationReason != null,
  };
  if (!valid || !_matchesExceptionGraph(row)) {
    throw const FormatException(
      'Blitz monitoring Student row is inconsistent.',
    );
  }
}

bool _hasAttemptTimes(TeacherBlitzMonitoringStudent row) {
  final startedAt = row.startedAt;
  final deadlineAt = row.deadlineAt;
  return (row.attemptNumber == 1 || row.attemptNumber == 2) &&
      startedAt != null &&
      deadlineAt != null &&
      deadlineAt.isAfter(startedAt);
}

/// Attempt #2 exists only through a started replacement; #1 can never show
/// one.
bool _matchesExceptionGraph(TeacherBlitzMonitoringStudent row) {
  final exception = row.attemptException;
  return switch (row.attemptNumber) {
    2 => exception != null && exception.replacementAttemptId != null,
    1 => exception == null || exception.replacementAttemptId == null,
    _ => true,
  };
}

void _validateRoster(
  TeacherBlitzMonitoringSummary summary,
  List<TeacherBlitzMonitoringStudent> students,
) {
  final ids = {for (final row in students) row.student.id.toLowerCase()};
  int count(TeacherBlitzMonitoringStudentStatus status) =>
      students.where((row) => row.status == status).length;
  if (ids.length != students.length ||
      students.length != summary.assigned ||
      count(TeacherBlitzMonitoringStudentStatus.notStarted) !=
          summary.notStarted ||
      count(TeacherBlitzMonitoringStudentStatus.inProgress) !=
          summary.inProgress ||
      count(TeacherBlitzMonitoringStudentStatus.finalized) !=
          summary.finalized ||
      count(TeacherBlitzMonitoringStudentStatus.waitingForTeacherReview) !=
          summary.waitingForTeacherReview ||
      students.where((row) => row.attemptException != null).length !=
          summary.attemptExceptionsGranted) {
    throw const FormatException(
      'Blitz monitoring rows do not match the summary.',
    );
  }
}
