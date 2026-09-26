import '../../domain/student_blitz.dart';
import 'student_dto_parse.dart';

class StudentActiveBlitzListDto {
  StudentActiveBlitzListDto._(List<StudentActiveBlitzSummary> items)
    : items = List<StudentActiveBlitzSummary>.unmodifiable(items);

  /// Exact `{data: [...]}`; server order is authoritative and kept.
  factory StudentActiveBlitzListDto.fromJson(Object? json) {
    final envelope = readExactStudentMap(
      json,
      context: 'Student active Blitz envelope',
      keys: const {'data'},
    );
    final ids = <String>{};
    final items = readStudentList(envelope, 'data').map((raw) {
      final item = _readActiveBlitz(raw);
      if (!ids.add(item.id.toLowerCase())) {
        throw const FormatException('Active Blitz IDs must be unique.');
      }
      return item;
    }).toList();
    return StudentActiveBlitzListDto._(items);
  }

  final List<StudentActiveBlitzSummary> items;

  List<StudentActiveBlitzSummary> toDomain() => items;
}

class StudentBlitzDetailDto {
  const StudentBlitzDetailDto._(this.detail);

  /// Exact pre-Start detail; any Question or answer key is a leak and fails.
  factory StudentBlitzDetailDto.fromJson(Object? json) {
    final map = readExactStudentMap(
      json,
      context: 'Student Blitz detail',
      keys: const {
        'id',
        'topic',
        'title',
        'description',
        'student_instructions',
        'status',
        'duration_seconds',
        'total_possible_points',
        'timing',
        'attempts',
      },
    );
    final attempts = _readAttemptSummary(map['attempts']);
    return StudentBlitzDetailDto._(
      StudentBlitzDetail(
        id: readStudentCanonicalUuid(map, 'id'),
        topic: _readTopic(map['topic']),
        title: readStudentNonBlankString(map, 'title'),
        description: readStudentNullableString(map, 'description'),
        studentInstructions: readStudentNonBlankString(
          map,
          'student_instructions',
        ),
        status: StudentBlitzStatus.parse(
          readStudentNonBlankString(map, 'status'),
        ),
        durationSeconds: _readDurationSeconds(map),
        totalPossiblePoints: readStudentNonNegativeNumber(
          map,
          'total_possible_points',
        ),
        timing: _readTiming(map['timing'], attempts),
        attempts: attempts,
      ),
    );
  }

  final StudentBlitzDetail detail;

  StudentBlitzDetail toDomain() => detail;
}

StudentActiveBlitzSummary _readActiveBlitz(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student active Blitz',
    keys: const {
      'id',
      'topic',
      'title',
      'status',
      'duration_seconds',
      'timing',
      'attempts',
    },
  );
  final attempts = _readAttemptSummary(map['attempts']);
  return StudentActiveBlitzSummary(
    id: readStudentCanonicalUuid(map, 'id'),
    topic: _readTopic(map['topic']),
    title: readStudentNonBlankString(map, 'title'),
    status: StudentBlitzStatus.parse(readStudentNonBlankString(map, 'status')),
    durationSeconds: _readDurationSeconds(map),
    timing: _readTiming(map['timing'], attempts),
    attempts: attempts,
  );
}

StudentBlitzTopicSummary _readTopic(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student Blitz Topic',
    keys: const {'id', 'title'},
  );
  return StudentBlitzTopicSummary(
    id: readStudentCanonicalUuid(map, 'id'),
    title: readStudentNonBlankString(map, 'title'),
  );
}

int _readDurationSeconds(Map<String, Object?> map) {
  final duration = readStudentInt(map, 'duration_seconds');
  if (duration <= 0) {
    throw const FormatException('Blitz duration must be positive.');
  }
  return duration;
}

StudentBlitzAttemptSummary _readAttemptSummary(Object? json) {
  final map = readExactStudentMap(
    json,
    context: 'Student Blitz attempt summary',
    keys: const {
      'normal_attempts',
      'normal_used',
      'in_progress_attempt_id',
      'additional_exception_granted',
      'replacement_attempt_available',
    },
  );
  final normalAttempts = readStudentInt(map, 'normal_attempts');
  final normalUsed = readStudentInt(map, 'normal_used');
  final inProgressAttemptId = map['in_progress_attempt_id'] == null
      ? null
      : readStudentCanonicalUuid(map, 'in_progress_attempt_id');
  final exceptionGranted = _readBool(map, 'additional_exception_granted');
  final replacementAvailable = _readBool(map, 'replacement_attempt_available');
  final valid =
      normalAttempts == 1 &&
      (normalUsed == 0 || normalUsed == 1) &&
      (normalUsed == 1 ||
          (inProgressAttemptId == null &&
              !exceptionGranted &&
              !replacementAvailable)) &&
      (!replacementAvailable ||
          (exceptionGranted && inProgressAttemptId == null));
  if (!valid) {
    throw const FormatException('Blitz attempt summary is inconsistent.');
  }
  return StudentBlitzAttemptSummary(
    normalAttempts: normalAttempts,
    normalUsed: normalUsed,
    inProgressAttemptId: inProgressAttemptId,
    additionalExceptionGranted: exceptionGranted,
    replacementAttemptAvailable: replacementAvailable,
  );
}

StudentBlitzTiming _readTiming(
  Object? json,
  StudentBlitzAttemptSummary attempts,
) {
  final map = readExactStudentMap(
    json,
    context: 'Student Blitz timing',
    keys: const {
      'mode',
      'server_now',
      'synchronized_ends_at',
      'deadline_at',
      'remaining_seconds',
    },
  );
  final remaining = map['remaining_seconds'];
  if (remaining != null && (remaining is! int || remaining < 0)) {
    throw const FormatException(
      'remaining_seconds must be a nullable non-negative integer.',
    );
  }
  final timing = StudentBlitzTiming(
    mode: StudentBlitzTimerMode.parse(readStudentNonBlankString(map, 'mode')),
    serverNow: readStudentWholeSecondUtcTimestamp(map, 'server_now'),
    synchronizedEndsAt: readStudentNullableWholeSecondUtcTimestamp(
      map,
      'synchronized_ends_at',
    ),
    deadlineAt: readStudentNullableWholeSecondUtcTimestamp(map, 'deadline_at'),
    remainingSeconds: remaining as int?,
  );
  _validateTiming(timing, attempts);
  return timing;
}

void _validateTiming(
  StudentBlitzTiming timing,
  StudentBlitzAttemptSummary attempts,
) {
  final synchronized = timing.mode == StudentBlitzTimerMode.synchronized;
  final commonEnd = timing.synchronizedEndsAt;
  final deadline = timing.deadlineAt;
  if (synchronized != (commonEnd != null) ||
      (deadline == null) != (timing.remainingSeconds == null)) {
    throw const FormatException('Blitz timing shape is inconsistent.');
  }
  if (attempts.replacementAttemptAvailable) {
    // The replacement's full duration starts only when the server starts it.
    if (deadline != null) {
      throw const FormatException(
        'An available replacement has no effective deadline.',
      );
    }
    return;
  }
  // The #1 deadline equals the common end; a #2 deadline may pass it.
  final followsCommonEnd = synchronized && !attempts.additionalExceptionGranted;
  if (attempts.isFinished) {
    // A finished latest Attempt keeps its own deadline, which may already be
    // in the past, and reports no remaining time.
    if (deadline == null ||
        timing.remainingSeconds != 0 ||
        (followsCommonEnd && !deadline.isAtSameMomentAs(commonEnd!))) {
      throw const FormatException(
        'A finished Blitz Attempt timing is inconsistent.',
      );
    }
    return;
  }
  if (deadline == null) {
    if (synchronized || attempts.inProgressAttemptId != null) {
      throw const FormatException('An executable Blitz requires a deadline.');
    }
    return;
  }
  if ((!synchronized && attempts.inProgressAttemptId == null) ||
      (followsCommonEnd && !deadline.isAtSameMomentAs(commonEnd!)) ||
      deadline.isBefore(timing.serverNow) ||
      timing.remainingSeconds !=
          deadline.millisecondsSinceEpoch ~/ 1000 -
              timing.serverNow.millisecondsSinceEpoch ~/ 1000) {
    throw const FormatException(
      'Blitz deadline and remaining seconds are inconsistent.',
    );
  }
}

bool _readBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('$key must be a boolean.');
}
