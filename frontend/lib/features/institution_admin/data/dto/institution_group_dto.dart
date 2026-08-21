import '../../domain/institution_group.dart';

class InstitutionGroupDto {
  const InstitutionGroupDto({
    required this.id,
    required this.name,
    required this.level,
    required this.subjectDirection,
    required this.description,
    required this.status,
    required this.teachersCount,
    required this.studentsCount,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InstitutionGroupDto.fromJson(Object? json) {
    final map = _readExactMap(
      json,
      context: 'Institution Group resource',
      keys: _groupKeys,
    );
    final status = InstitutionGroupStatus.parse(
      _readNonBlankString(map, 'status'),
    );
    final archivedAt = _readNullableUtcTimestamp(map, 'archived_at');
    if (status == InstitutionGroupStatus.active && archivedAt != null) {
      throw const FormatException(
        'An active Institution Group cannot be archived.',
      );
    }
    if (status == InstitutionGroupStatus.archived && archivedAt == null) {
      throw const FormatException(
        'An archived Institution Group requires archived_at.',
      );
    }

    return InstitutionGroupDto(
      id: _readCanonicalUuid(map, 'id'),
      name: _readNonBlankString(map, 'name'),
      level: _readNullableString(map, 'level'),
      subjectDirection: _readNullableString(map, 'subject_direction'),
      description: _readNullableString(map, 'description'),
      status: status,
      teachersCount: _readNonNegativeInt(map, 'teachers_count'),
      studentsCount: _readNonNegativeInt(map, 'students_count'),
      archivedAt: archivedAt,
      createdAt: _readRequiredUtcTimestamp(map, 'created_at'),
      updatedAt: _readRequiredUtcTimestamp(map, 'updated_at'),
    );
  }

  final String id;
  final String name;
  final String? level;
  final String? subjectDirection;
  final String? description;
  final InstitutionGroupStatus status;
  final int teachersCount;
  final int studentsCount;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  InstitutionGroup toDomain() {
    return InstitutionGroup(
      id: id,
      name: name,
      level: level,
      subjectDirection: subjectDirection,
      description: description,
      status: status,
      teachersCount: teachersCount,
      studentsCount: studentsCount,
      archivedAt: archivedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

bool isCanonicalInstitutionGroupId(String value) {
  return _canonicalUuidPattern.hasMatch(value);
}

const _groupKeys = <String>{
  'id',
  'name',
  'level',
  'subject_direction',
  'description',
  'status',
  'teachers_count',
  'students_count',
  'archived_at',
  'created_at',
  'updated_at',
};

final _canonicalUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

Map<String, Object?> _readExactMap(
  Object? value, {
  required String context,
  required Set<String> keys,
}) {
  if (value is! Map) {
    throw FormatException('$context must be an object.');
  }

  final map = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw FormatException('$context contains a non-string key.');
    }
    map[key] = entry.value;
  }

  if (map.length != keys.length || !map.keys.toSet().containsAll(keys)) {
    throw FormatException('$context has missing or unknown keys.');
  }

  return map;
}

String _readNonBlankString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  throw FormatException('$key must be a non-blank string.');
}

String _readCanonicalUuid(Map<String, Object?> map, String key) {
  final value = _readNonBlankString(map, key);
  if (!_canonicalUuidPattern.hasMatch(value)) {
    throw FormatException('$key must be a canonical UUID.');
  }

  return value;
}

String? _readNullableString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null || value is String) {
    return value as String?;
  }

  throw FormatException('$key must be a nullable string.');
}

int _readNonNegativeInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int && value >= 0) {
    return value;
  }

  throw FormatException('$key must be a non-negative JSON integer.');
}

DateTime _readRequiredUtcTimestamp(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('$key must be a UTC timestamp.');
  }

  return _parseUtcTimestamp(value, key);
}

DateTime? _readNullableUtcTimestamp(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('$key must be a nullable UTC timestamp.');
  }

  return _parseUtcTimestamp(value, key);
}

DateTime _parseUtcTimestamp(String value, String key) {
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
