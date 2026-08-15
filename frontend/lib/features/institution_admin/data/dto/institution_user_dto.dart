import '../../domain/institution_user.dart';

class InstitutionUserDto {
  const InstitutionUserDto({
    required this.id,
    required this.role,
    required this.fullName,
    required this.loginName,
    required this.email,
    required this.phone,
    required this.isActive,
    required this.mustChangePassword,
    required this.lastLoginAt,
    required this.deactivatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InstitutionUserDto.fromJson(Object? json) {
    final map = _readExactMap(
      json,
      context: 'Institution User resource',
      keys: _userKeys,
    );
    final id = _readCanonicalUuid(map, 'id');
    final role = InstitutionUserRole.parse(_readNonBlankString(map, 'role'));
    final isActive = _readBool(map, 'is_active');
    final deactivatedAt = _readNullableUtcTimestamp(map, 'deactivated_at');
    if (isActive && deactivatedAt != null) {
      throw const FormatException(
        'An active Institution User cannot be deactivated.',
      );
    }
    if (!isActive && deactivatedAt == null) {
      throw const FormatException(
        'An inactive Institution User requires deactivated_at.',
      );
    }

    return InstitutionUserDto(
      id: id,
      role: role,
      fullName: _readNonBlankString(map, 'full_name'),
      loginName: _readNonBlankString(map, 'login_name'),
      email: _readNullableString(map, 'email'),
      phone: _readNullableString(map, 'phone'),
      isActive: isActive,
      mustChangePassword: _readBool(map, 'must_change_password'),
      lastLoginAt: _readNullableUtcTimestamp(map, 'last_login_at'),
      deactivatedAt: deactivatedAt,
      createdAt: _readRequiredUtcTimestamp(map, 'created_at'),
      updatedAt: _readRequiredUtcTimestamp(map, 'updated_at'),
    );
  }

  final String id;
  final InstitutionUserRole role;
  final String fullName;
  final String loginName;
  final String? email;
  final String? phone;
  final bool isActive;
  final bool mustChangePassword;
  final DateTime? lastLoginAt;
  final DateTime? deactivatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  InstitutionUser toDomain() {
    return InstitutionUser(
      id: id,
      role: role,
      fullName: fullName,
      loginName: loginName,
      email: email,
      phone: phone,
      isActive: isActive,
      mustChangePassword: mustChangePassword,
      lastLoginAt: lastLoginAt,
      deactivatedAt: deactivatedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

bool isCanonicalInstitutionUserId(String value) {
  return _canonicalUuidPattern.hasMatch(value);
}

const _userKeys = <String>{
  'id',
  'role',
  'full_name',
  'login_name',
  'email',
  'phone',
  'is_active',
  'must_change_password',
  'last_login_at',
  'deactivated_at',
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
  if (!isCanonicalInstitutionUserId(value)) {
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

bool _readBool(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is bool) {
    return value;
  }

  throw FormatException('$key must be a JSON boolean.');
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
  if (!value.endsWith('Z')) {
    throw FormatException('$key must end in Z.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('$key must be a valid UTC timestamp.');
  }

  return parsed;
}
