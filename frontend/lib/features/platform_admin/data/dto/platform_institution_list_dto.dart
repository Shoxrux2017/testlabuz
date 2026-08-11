import '../../domain/platform_institution.dart';
import '../../domain/platform_institution_list.dart';

class PlatformInstitutionListDto {
  const PlatformInstitutionListDto({
    required this.institutions,
    required this.pagination,
  });

  factory PlatformInstitutionListDto.fromJson(Object? json) {
    final envelope = _readRequiredMap(json, 'institution list envelope');
    final data = envelope['data'];
    if (data is! List<Object?>) {
      throw const FormatException('Missing required institution list data.');
    }

    return PlatformInstitutionListDto(
      institutions: List<PlatformInstitutionSummaryDto>.unmodifiable(
        data.map(PlatformInstitutionSummaryDto.fromJson),
      ),
      pagination: PlatformInstitutionPaginationDto.fromJson(
        _readPagination(envelope),
      ),
    );
  }

  final List<PlatformInstitutionSummaryDto> institutions;
  final PlatformInstitutionPaginationDto pagination;

  PlatformInstitutionListPage toDomain() {
    return PlatformInstitutionListPage(
      institutions: List<PlatformInstitutionSummary>.unmodifiable(
        institutions.map((institution) => institution.toDomain()),
      ),
      pagination: pagination.toDomain(),
    );
  }

  static Object? _readPagination(Map<Object?, Object?> envelope) {
    final meta = _readRequiredMap(envelope['meta'], 'institution list meta');

    return meta['pagination'];
  }
}

class PlatformInstitutionSummaryDto {
  const PlatformInstitutionSummaryDto({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.contactEmail,
    required this.contactPhone,
    required this.createdAt,
    required this.updatedAt,
    required this.userCounts,
  });

  factory PlatformInstitutionSummaryDto.fromJson(Object? json) {
    final map = _readRequiredMap(json, 'institution summary');

    return PlatformInstitutionSummaryDto(
      id: _readRequiredString(map, 'id'),
      name: _readRequiredString(map, 'name'),
      type: PlatformInstitutionType.parse(_readRequiredString(map, 'type')),
      status: PlatformInstitutionStatus.parse(
        _readRequiredString(map, 'status'),
      ),
      contactEmail: _readNullableString(map, 'contact_email'),
      contactPhone: _readNullableString(map, 'contact_phone'),
      createdAt: _readRequiredUtcDateTime(map, 'created_at'),
      updatedAt: _readRequiredUtcDateTime(map, 'updated_at'),
      userCounts: PlatformInstitutionUserCountsDto.fromJson(map['user_counts']),
    );
  }

  final String id;
  final String name;
  final PlatformInstitutionType type;
  final PlatformInstitutionStatus status;
  final String? contactEmail;
  final String? contactPhone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PlatformInstitutionUserCountsDto userCounts;

  PlatformInstitutionSummary toDomain() {
    return PlatformInstitutionSummary(
      id: id,
      name: name,
      type: type,
      status: status,
      contactEmail: contactEmail,
      contactPhone: contactPhone,
      createdAt: createdAt,
      updatedAt: updatedAt,
      userCounts: userCounts.toDomain(),
    );
  }
}

class PlatformInstitutionUserCountsDto {
  const PlatformInstitutionUserCountsDto({
    required this.total,
    required this.active,
  });

  factory PlatformInstitutionUserCountsDto.fromJson(Object? json) {
    final map = _readRequiredMap(json, 'institution user counts');
    final total = _readRequiredNonNegativeInt(map, 'total');
    final active = _readRequiredNonNegativeInt(map, 'active');
    if (active > total) {
      throw const FormatException('Active user count exceeds total count.');
    }

    return PlatformInstitutionUserCountsDto(total: total, active: active);
  }

  final int total;
  final int active;

  PlatformInstitutionUserCounts toDomain() {
    return PlatformInstitutionUserCounts(total: total, active: active);
  }
}

class PlatformInstitutionPaginationDto {
  const PlatformInstitutionPaginationDto({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory PlatformInstitutionPaginationDto.fromJson(Object? json) {
    final map = _readRequiredMap(json, 'institution list pagination');
    final page = _readRequiredNonNegativeInt(map, 'page');
    final perPage = _readRequiredNonNegativeInt(map, 'per_page');
    final total = _readRequiredNonNegativeInt(map, 'total');
    final lastPage = _readRequiredNonNegativeInt(map, 'last_page');

    if (page < 1) {
      throw const FormatException('Pagination page must be at least 1.');
    }

    if (perPage < 1 || perPage > 100) {
      throw const FormatException('Pagination per_page is out of bounds.');
    }

    if (lastPage < 1) {
      throw const FormatException('Pagination last_page must be at least 1.');
    }

    return PlatformInstitutionPaginationDto(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    );
  }

  final int page;
  final int perPage;
  final int total;
  final int lastPage;

  PlatformInstitutionPagination toDomain() {
    return PlatformInstitutionPagination(
      page: page,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
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

int _readRequiredNonNegativeInt(Map<Object?, Object?> json, String key) {
  final value = json[key];

  if (value is int && value >= 0) {
    return value;
  }

  throw FormatException('Missing required non-negative integer field: $key.');
}

DateTime _readRequiredUtcDateTime(Map<Object?, Object?> json, String key) {
  final value = _readRequiredString(json, key);
  final parsed = DateTime.parse(value);

  return parsed.toUtc();
}
