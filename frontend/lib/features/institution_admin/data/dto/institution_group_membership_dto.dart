import '../../domain/institution_group_membership.dart';

class InstitutionGroupMembershipDto {
  const InstitutionGroupMembershipDto({
    required this.id,
    required this.fullName,
    required this.loginName,
    required this.email,
    required this.phone,
    required this.isActive,
    required this.startedAt,
  });

  factory InstitutionGroupMembershipDto.fromJson(Object? json) {
    final map = readExactMembershipMap(
      json,
      context: 'Institution Group membership resource',
      keys: _membershipKeys,
    );
    return InstitutionGroupMembershipDto(
      id: readCanonicalMembershipUuid(map, 'id'),
      fullName: readNonBlankMembershipString(map, 'full_name'),
      loginName: readNonBlankMembershipString(map, 'login_name'),
      email: readNullableMembershipString(map, 'email'),
      phone: readNullableMembershipString(map, 'phone'),
      isActive: readMembershipBool(map, 'is_active'),
      startedAt: readMembershipUtcTimestamp(map, 'started_at'),
    );
  }

  final String id;
  final String fullName;
  final String loginName;
  final String? email;
  final String? phone;
  final bool isActive;
  final DateTime startedAt;

  InstitutionGroupMembership toDomain() => InstitutionGroupMembership(
    id: id,
    fullName: fullName,
    loginName: loginName,
    email: email,
    phone: phone,
    isActive: isActive,
    startedAt: startedAt,
  );
}

bool isCanonicalInstitutionGroupMembershipId(String value) =>
    _canonicalUuidPattern.hasMatch(value);

const _membershipKeys = <String>{
  'id',
  'full_name',
  'login_name',
  'email',
  'phone',
  'is_active',
  'started_at',
};

final _canonicalUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

Map<String, Object?> readExactMembershipMap(
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

String readNonBlankMembershipString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('$key must be a non-blank string.');
}

String readCanonicalMembershipUuid(Map<String, Object?> map, String key) {
  final value = readNonBlankMembershipString(map, key);
  if (!isCanonicalInstitutionGroupMembershipId(value)) {
    throw FormatException('$key must be a canonical UUID.');
  }
  return value;
}

String? readNullableMembershipString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null || value is String) {
    return value as String?;
  }
  throw FormatException('$key must be a nullable string.');
}

bool readMembershipBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('$key must be a JSON boolean.');
}

DateTime readMembershipUtcTimestamp(Map<String, Object?> map, String key) {
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
