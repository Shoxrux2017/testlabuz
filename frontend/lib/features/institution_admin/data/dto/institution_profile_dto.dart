import '../../../../core/network/api_envelope.dart';
import '../../domain/institution_profile.dart';

const institutionProfileUpdateSuccessMessage =
    'Institution profile updated successfully.';

class InstitutionProfileDto {
  const InstitutionProfileDto({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.contactEmail,
    required this.contactPhone,
    required this.address,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InstitutionProfileDto.fromJson(Object? json) {
    final map = _readRequiredMap(json, 'institution profile');
    _requireNullableKeys(map, const [
      'contact_email',
      'contact_phone',
      'address',
      'description',
    ]);

    final id = _readRequiredString(map, 'id');
    if (!_canonicalUuid.hasMatch(id)) {
      throw const FormatException('Invalid institution profile ID.');
    }

    return InstitutionProfileDto(
      id: id,
      name: _readRequiredNonEmptyString(map, 'name'),
      type: InstitutionProfileType.parse(_readRequiredString(map, 'type')),
      status: InstitutionProfileStatus.parse(
        _readRequiredString(map, 'status'),
      ),
      contactEmail: _readRequiredNullableString(map, 'contact_email'),
      contactPhone: _readRequiredNullableString(map, 'contact_phone'),
      address: _readRequiredNullableString(map, 'address'),
      description: _readRequiredNullableString(map, 'description'),
      createdAt: _readUtcTimestamp(map, 'created_at'),
      updatedAt: _readUtcTimestamp(map, 'updated_at'),
    );
  }

  final String id;
  final String name;
  final InstitutionProfileType type;
  final InstitutionProfileStatus status;
  final String? contactEmail;
  final String? contactPhone;
  final String? address;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  InstitutionProfile toDomain() {
    return InstitutionProfile(
      id: id,
      name: name,
      type: type,
      status: status,
      contactEmail: contactEmail,
      contactPhone: contactPhone,
      address: address,
      description: description,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class InstitutionProfileGetResponseDto {
  const InstitutionProfileGetResponseDto({required this.profile});

  factory InstitutionProfileGetResponseDto.fromJson(Object? json) {
    final envelope = ApiSuccessEnvelope.fromJson(
      json,
      InstitutionProfileDto.fromJson,
    );

    return InstitutionProfileGetResponseDto(profile: envelope.data);
  }

  final InstitutionProfileDto profile;
}

class InstitutionProfileUpdateResponseDto {
  const InstitutionProfileUpdateResponseDto({required this.profile});

  factory InstitutionProfileUpdateResponseDto.fromJson(Object? json) {
    final map = _readRequiredMap(json, 'institution profile update response');
    if (map['message'] != institutionProfileUpdateSuccessMessage) {
      throw const FormatException(
        'Missing exact institution profile update success message.',
      );
    }

    final envelope = ApiSuccessEnvelope.fromJson(
      map,
      InstitutionProfileDto.fromJson,
    );

    return InstitutionProfileUpdateResponseDto(profile: envelope.data);
  }

  final InstitutionProfileDto profile;
}

final RegExp _canonicalUuid = RegExp(
  r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$',
);
final RegExp _utcTimestamp = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?Z$',
);

Map<Object?, Object?> _readRequiredMap(Object? value, String context) {
  if (value is Map<Object?, Object?>) {
    return value;
  }

  if (value is Map) {
    return Map<Object?, Object?>.from(value);
  }

  throw FormatException('Expected object for $context.');
}

String _readRequiredString(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value is String) {
    return value;
  }

  throw FormatException('Missing required string field: $key.');
}

String _readRequiredNonEmptyString(Map<Object?, Object?> map, String key) {
  final value = _readRequiredString(map, key);
  if (value.isEmpty) {
    throw FormatException('Empty required string field: $key.');
  }

  return value;
}

String? _readRequiredNullableString(Map<Object?, Object?> map, String key) {
  if (!map.containsKey(key)) {
    throw FormatException('Missing required nullable field: $key.');
  }

  final value = map[key];
  if (value == null || value is String) {
    return value as String?;
  }

  throw FormatException('Invalid nullable string field: $key.');
}

void _requireNullableKeys(Map<Object?, Object?> map, List<String> keys) {
  for (final key in keys) {
    if (!map.containsKey(key)) {
      throw FormatException('Missing required nullable field: $key.');
    }
  }
}

DateTime _readUtcTimestamp(Map<Object?, Object?> map, String key) {
  final value = _readRequiredString(map, key);
  final match = _utcTimestamp.firstMatch(value);
  if (match == null) {
    throw FormatException('Invalid UTC timestamp field: $key.');
  }

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final rawFraction = match.group(7) ?? '';
  final fraction = rawFraction.length > 6
      ? rawFraction.substring(0, 6)
      : rawFraction.padRight(6, '0');
  final microsecond = fraction.isEmpty ? 0 : int.parse(fraction);
  final timestamp = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
    microsecond ~/ 1000,
    microsecond % 1000,
  );

  if (timestamp.year != year ||
      timestamp.month != month ||
      timestamp.day != day ||
      timestamp.hour != hour ||
      timestamp.minute != minute ||
      timestamp.second != second) {
    throw FormatException('Invalid calendar timestamp field: $key.');
  }

  return timestamp;
}
