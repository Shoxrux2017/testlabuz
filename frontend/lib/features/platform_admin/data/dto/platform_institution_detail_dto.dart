import '../../domain/platform_institution.dart';
import '../../domain/platform_institution_detail.dart';
import 'platform_institution_list_dto.dart';

class PlatformInstitutionDetailDto {
  const PlatformInstitutionDetailDto({
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
    required this.userCounts,
  });

  factory PlatformInstitutionDetailDto.fromJson(Object? json) {
    final envelope = _readRequiredMap(json, 'institution detail envelope');
    final data = _readRequiredMap(envelope['data'], 'institution detail data');

    return PlatformInstitutionDetailDto(
      id: _readRequiredString(data, 'id'),
      name: _readRequiredString(data, 'name'),
      type: PlatformInstitutionType.parse(_readRequiredString(data, 'type')),
      status: PlatformInstitutionStatus.parse(
        _readRequiredString(data, 'status'),
      ),
      contactEmail: _readNullableString(data, 'contact_email'),
      contactPhone: _readNullableString(data, 'contact_phone'),
      address: _readNullableString(data, 'address'),
      description: _readNullableString(data, 'description'),
      createdAt: _readRequiredRfc3339DateTime(data, 'created_at'),
      updatedAt: _readRequiredRfc3339DateTime(data, 'updated_at'),
      userCounts: PlatformInstitutionUserCountsDto.fromJson(
        data['user_counts'],
      ),
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
  final PlatformInstitutionUserCountsDto userCounts;

  PlatformInstitutionDetail toDomain() {
    return PlatformInstitutionDetail(
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
      userCounts: userCounts.toDomain(),
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
