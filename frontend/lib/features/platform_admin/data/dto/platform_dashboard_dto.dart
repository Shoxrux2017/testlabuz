import '../../../../core/network/api_envelope.dart';
import '../../domain/platform_dashboard.dart';

class PlatformDashboardDto {
  const PlatformDashboardDto({
    required this.institutions,
    required this.users,
    required this.recentInstitutions,
  });

  factory PlatformDashboardDto.fromJson(Object? json) {
    return ApiSuccessEnvelope.fromJson(json, (data) {
      final map = _readRequiredMap(data, 'platform dashboard');

      return PlatformDashboardDto(
        institutions: PlatformInstitutionCountsDto.fromJson(
          map['institutions'],
        ),
        users: PlatformUserCountsDto.fromJson(map['users']),
        recentInstitutions: _readRecentInstitutions(map['recent_institutions']),
      );
    }).data;
  }

  final PlatformInstitutionCountsDto institutions;
  final PlatformUserCountsDto users;
  final List<RecentPlatformInstitutionDto> recentInstitutions;

  PlatformDashboard toDomain() {
    return PlatformDashboard(
      institutions: institutions.toDomain(),
      users: users.toDomain(),
      recentInstitutions: List<RecentPlatformInstitution>.unmodifiable(
        recentInstitutions.map((institution) => institution.toDomain()),
      ),
    );
  }

  static List<RecentPlatformInstitutionDto> _readRecentInstitutions(
    Object? value,
  ) {
    if (value is! List<Object?>) {
      throw const FormatException('Missing required recent_institutions list.');
    }

    return List<RecentPlatformInstitutionDto>.unmodifiable(
      value.map(RecentPlatformInstitutionDto.fromJson),
    );
  }
}

class PlatformInstitutionCountsDto {
  const PlatformInstitutionCountsDto({
    required this.total,
    required this.active,
    required this.inactive,
  });

  factory PlatformInstitutionCountsDto.fromJson(Object? json) {
    final map = _readRequiredMap(json, 'institution counts');

    return PlatformInstitutionCountsDto(
      total: _readRequiredNonNegativeInt(map, 'total'),
      active: _readRequiredNonNegativeInt(map, 'active'),
      inactive: _readRequiredNonNegativeInt(map, 'inactive'),
    );
  }

  final int total;
  final int active;
  final int inactive;

  PlatformInstitutionCounts toDomain() {
    return PlatformInstitutionCounts(
      total: total,
      active: active,
      inactive: inactive,
    );
  }
}

class PlatformUserCountsDto {
  const PlatformUserCountsDto({required this.total, required this.active});

  factory PlatformUserCountsDto.fromJson(Object? json) {
    final map = _readRequiredMap(json, 'user counts');

    return PlatformUserCountsDto(
      total: _readRequiredNonNegativeInt(map, 'total'),
      active: _readRequiredNonNegativeInt(map, 'active'),
    );
  }

  final int total;
  final int active;

  PlatformUserCounts toDomain() {
    return PlatformUserCounts(total: total, active: active);
  }
}

class RecentPlatformInstitutionDto {
  const RecentPlatformInstitutionDto({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  factory RecentPlatformInstitutionDto.fromJson(Object? json) {
    final map = _readRequiredMap(json, 'recent institution');

    return RecentPlatformInstitutionDto(
      id: _readRequiredUuidString(map, 'id'),
      name: _readRequiredString(map, 'name'),
      type: PlatformInstitutionType.parse(_readRequiredString(map, 'type')),
      status: PlatformInstitutionStatus.parse(
        _readRequiredString(map, 'status'),
      ),
      createdAt: _readRequiredUtcDateTime(map, 'created_at'),
    );
  }

  final String id;
  final String name;
  final PlatformInstitutionType type;
  final PlatformInstitutionStatus status;
  final DateTime createdAt;

  RecentPlatformInstitution toDomain() {
    return RecentPlatformInstitution(
      id: id,
      name: name,
      type: type,
      status: status,
      createdAt: createdAt,
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

String _readRequiredUuidString(Map<Object?, Object?> json, String key) {
  final value = _readRequiredString(json, key);
  final uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  if (uuidPattern.hasMatch(value)) {
    return value;
  }

  throw FormatException('Invalid UUID field: $key.');
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
