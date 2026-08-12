import '../../domain/platform_institution.dart';
import '../../domain/platform_institution_lifecycle.dart';

class PlatformInstitutionLifecycleResponseDto {
  const PlatformInstitutionLifecycleResponseDto({
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
    required this.message,
  });

  factory PlatformInstitutionLifecycleResponseDto.fromJson(
    Object? json, {
    required String requestedInstitutionId,
    required PlatformInstitutionStatus targetStatus,
  }) {
    final envelope = _readRequiredMap(json, 'institution lifecycle envelope');
    final data = _readRequiredMap(
      envelope['data'],
      'institution lifecycle data',
    );
    final id = _readRequiredString(data, 'id');
    final status = PlatformInstitutionStatus.parse(
      _readRequiredString(data, 'status'),
    );

    if (id != requestedInstitutionId) {
      throw const FormatException(
        'Institution lifecycle response ID did not match request.',
      );
    }

    if (status != targetStatus) {
      throw const FormatException(
        'Institution lifecycle response status did not match target.',
      );
    }

    return PlatformInstitutionLifecycleResponseDto(
      id: id,
      name: _readRequiredString(data, 'name'),
      type: PlatformInstitutionType.parse(_readRequiredString(data, 'type')),
      status: status,
      contactEmail: _readNullableString(data, 'contact_email'),
      contactPhone: _readNullableString(data, 'contact_phone'),
      address: _readNullableString(data, 'address'),
      description: _readNullableString(data, 'description'),
      createdAt: _readRequiredRfc3339DateTime(data, 'created_at'),
      updatedAt: _readRequiredRfc3339DateTime(data, 'updated_at'),
      message: _readRequiredString(envelope, 'message'),
    );
  }

  final String id;
  final String name;
  final PlatformInstitutionType type;
  final PlatformInstitutionStatus status;
  final String? contactEmail;
  final String? contactPhone;
  final String? address;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String message;

  PlatformInstitutionLifecycleResult toDomain() {
    return PlatformInstitutionLifecycleResult(
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
      message: message,
    );
  }
}

Map<Object?, Object?> _readRequiredMap(Object? value, String context) {
  if (value is Map<Object?, Object?>) {
    return value;
  }

  if (value is Map) {
    return Map<Object?, Object?>.from(value);
  }

  throw FormatException('Expected object for $context.');
}

String _readRequiredString(Map<Object?, Object?> json, String key) {
  final value = json[key];

  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  throw FormatException('Missing required string field: $key.');
}

String? _readNullableString(Map<Object?, Object?> json, String key) {
  final value = json[key];

  if (value == null || value is String) {
    return value as String?;
  }

  throw FormatException('Expected nullable string field: $key.');
}

DateTime _readRequiredRfc3339DateTime(Map<Object?, Object?> json, String key) {
  final value = _readRequiredString(json, key);
  if (!_rfc3339TimestampPattern.hasMatch(value)) {
    throw FormatException('Invalid RFC3339 timestamp field: $key.');
  }

  return DateTime.parse(value).toUtc();
}

final _rfc3339TimestampPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
);
