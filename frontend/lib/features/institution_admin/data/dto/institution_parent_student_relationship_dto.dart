import '../../domain/institution_parent_student_relationship.dart';
import '../../domain/institution_parent_student_relationship_mutation.dart';

class InstitutionParentStudentRelationshipDto {
  const InstitutionParentStudentRelationshipDto({
    required this.id,
    required this.parentId,
    required this.studentId,
    required this.startedAt,
    required this.endedAt,
    required this.relatedUser,
  });

  factory InstitutionParentStudentRelationshipDto.fromJson(
    Object? json, {
    required InstitutionParentStudentPerspective perspective,
    required String anchorId,
  }) {
    final map = readExactParentStudentMap(
      json,
      context: 'Parent-Student relationship resource',
      keys: const {
        'id',
        'parent_id',
        'student_id',
        'started_at',
        'ended_at',
        'related_user',
      },
    );
    final id = readCanonicalParentStudentUuid(map, 'id');
    final parentId = readCanonicalParentStudentUuid(map, 'parent_id');
    final studentId = readCanonicalParentStudentUuid(map, 'student_id');
    final startedAt = readParentStudentUtcTimestamp(map, 'started_at');
    if (parentId.toLowerCase() == studentId.toLowerCase()) {
      throw const FormatException(
        'Parent and Student relationship targets must be distinct.',
      );
    }
    if (map['ended_at'] != null) {
      throw const FormatException(
        'Current relationship ended_at must be null.',
      );
    }
    final relatedUser = InstitutionParentStudentRelatedUserDto.fromJson(
      map['related_user'],
    );
    final matchesDirection = switch (perspective) {
      InstitutionParentStudentPerspective.byParent =>
        parentId.toLowerCase() == anchorId.toLowerCase() &&
            relatedUser.id.toLowerCase() == studentId.toLowerCase(),
      InstitutionParentStudentPerspective.byStudent =>
        studentId.toLowerCase() == anchorId.toLowerCase() &&
            relatedUser.id.toLowerCase() == parentId.toLowerCase(),
    };
    if (!matchesDirection) {
      throw const FormatException(
        'Relationship resource contradicts its anchor or perspective.',
      );
    }
    return InstitutionParentStudentRelationshipDto(
      id: id,
      parentId: parentId,
      studentId: studentId,
      startedAt: startedAt,
      endedAt: null,
      relatedUser: relatedUser,
    );
  }

  final String id;
  final String parentId;
  final String studentId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final InstitutionParentStudentRelatedUserDto relatedUser;

  InstitutionParentStudentRelationship toDomain() =>
      InstitutionParentStudentRelationship(
        id: id,
        parentId: parentId,
        studentId: studentId,
        startedAt: startedAt,
        endedAt: endedAt,
        relatedUser: relatedUser.toDomain(),
      );
}

class InstitutionParentStudentRelatedUserDto {
  const InstitutionParentStudentRelatedUserDto({
    required this.id,
    required this.fullName,
    required this.loginName,
    required this.email,
    required this.phone,
    required this.isActive,
  });

  factory InstitutionParentStudentRelatedUserDto.fromJson(Object? json) {
    final map = readExactParentStudentMap(
      json,
      context: 'Parent-Student related User resource',
      keys: const {
        'id',
        'full_name',
        'login_name',
        'email',
        'phone',
        'is_active',
      },
    );
    return InstitutionParentStudentRelatedUserDto(
      id: readCanonicalParentStudentUuid(map, 'id'),
      fullName: readNonBlankParentStudentString(map, 'full_name'),
      loginName: readNonBlankParentStudentString(map, 'login_name'),
      email: readNullableParentStudentString(map, 'email'),
      phone: readNullableParentStudentString(map, 'phone'),
      isActive: readParentStudentBool(map, 'is_active'),
    );
  }

  final String id;
  final String fullName;
  final String loginName;
  final String? email;
  final String? phone;
  final bool isActive;

  InstitutionParentStudentRelatedUser toDomain() =>
      InstitutionParentStudentRelatedUser(
        id: id,
        fullName: fullName,
        loginName: loginName,
        email: email,
        phone: phone,
        isActive: isActive,
      );
}

Map<String, Object?> readExactParentStudentMap(
  Object? value, {
  required String context,
  required Set<String> keys,
}) {
  if (value is! Map) {
    throw FormatException('$context must be an object.');
  }
  final map = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$context contains a non-string key.');
    }
    map[entry.key as String] = entry.value;
  }
  if (map.length != keys.length || !map.keys.toSet().containsAll(keys)) {
    throw FormatException('$context has missing or unknown keys.');
  }
  return map;
}

String readNonBlankParentStudentString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('$key must be a non-blank string.');
}

String readCanonicalParentStudentUuid(Map<String, Object?> map, String key) {
  final value = readNonBlankParentStudentString(map, key);
  if (!isCanonicalParentStudentUuid(value)) {
    throw FormatException('$key must be a canonical UUID.');
  }
  return value;
}

String? readNullableParentStudentString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null || value is String) {
    return value as String?;
  }
  throw FormatException('$key must be a nullable string.');
}

bool readParentStudentBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('$key must be a JSON boolean.');
}

DateTime readParentStudentUtcTimestamp(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('$key must be a UTC timestamp.');
  }
  final match = _utcTimestampPattern.firstMatch(value);
  if (match == null) {
    throw FormatException('$key must be an ISO-8601 timestamp ending in Z.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      !parsed.isUtc ||
      parsed.year != int.parse(match.group(1)!) ||
      parsed.month != int.parse(match.group(2)!) ||
      parsed.day != int.parse(match.group(3)!) ||
      parsed.hour != int.parse(match.group(4)!) ||
      parsed.minute != int.parse(match.group(5)!) ||
      parsed.second != int.parse(match.group(6) ?? '0')) {
    throw FormatException('$key must be a valid UTC timestamp.');
  }
  return parsed;
}

final _utcTimestampPattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?Z$',
);
