import '../../domain/teacher_blitz_attempt_exception.dart';
import 'teacher_dto_parse.dart';

const teacherBlitzAttemptExceptionGrantedMessage =
    'One additional Blitz attempt has been granted.';

class TeacherBlitzAttemptExceptionDto {
  const TeacherBlitzAttemptExceptionDto._(this.exception);

  /// Strict `201` grant or same-key replay for [expectedBlitzId] and
  /// [expectedStudentId]. Its replacement truth table is the grant one: an
  /// unused grant may be historical and no longer available.
  factory TeacherBlitzAttemptExceptionDto.fromJson(
    Object? json, {
    required String expectedBlitzId,
    required String expectedStudentId,
  }) {
    final envelope = readExactTeacherMap(
      json,
      context: 'Blitz attempt exception envelope',
      keys: const {'data', 'message'},
    );
    if (envelope['message'] != teacherBlitzAttemptExceptionGrantedMessage) {
      throw const FormatException(
        'Blitz attempt exception message is invalid.',
      );
    }
    final map = readExactTeacherMap(
      envelope['data'],
      context: 'Blitz attempt exception',
      keys: const {
        'id',
        'blitz_id',
        'student_id',
        'invalidated_attempt_id',
        'replacement_attempt_id',
        'reason_type',
        'reason',
        'granted_at',
        'replacement_attempt_available',
      },
    );
    final blitzId = readTeacherCanonicalUuid(map, 'blitz_id');
    final studentId = readTeacherCanonicalUuid(map, 'student_id');
    if (blitzId.toLowerCase() != expectedBlitzId.toLowerCase() ||
        studentId.toLowerCase() != expectedStudentId.toLowerCase()) {
      throw const FormatException(
        'Blitz attempt exception does not match its Blitz and Student.',
      );
    }
    final replacementAttemptId = readTeacherNullableCanonicalUuid(
      map,
      'replacement_attempt_id',
    );
    final available = readTeacherBool(map, 'replacement_attempt_available');
    if (replacementAttemptId != null && available) {
      throw const FormatException(
        'A started replacement attempt cannot still be available.',
      );
    }
    return TeacherBlitzAttemptExceptionDto._(
      TeacherBlitzAttemptException(
        id: readTeacherCanonicalUuid(map, 'id'),
        blitzId: blitzId,
        studentId: studentId,
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
      ),
    );
  }

  final TeacherBlitzAttemptException exception;

  TeacherBlitzAttemptException toDomain() => exception;
}

String readTeacherBlitzAttemptExceptionReason(
  Map<String, Object?> map,
  String key,
) {
  final value = readTeacherNonBlankString(map, key);
  if (!isValidTeacherBlitzAttemptExceptionReason(value)) {
    throw FormatException('$key must be at most 4000 characters.');
  }
  return value;
}

String? readTeacherNullableCanonicalUuid(Map<String, Object?> map, String key) {
  return map[key] == null ? null : readTeacherCanonicalUuid(map, key);
}

bool readTeacherBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('$key must be a JSON boolean.');
}

DateTime readTeacherWholeSecondUtcTimestamp(
  Map<String, Object?> map,
  String key,
) {
  final value = readTeacherRequiredUtcTimestamp(map, key);
  if (value.millisecond != 0 || value.microsecond != 0) {
    throw FormatException('$key must be a whole-second UTC timestamp.');
  }
  return value;
}

DateTime? readTeacherNullableWholeSecondUtcTimestamp(
  Map<String, Object?> map,
  String key,
) {
  return map[key] == null ? null : readTeacherWholeSecondUtcTimestamp(map, key);
}
