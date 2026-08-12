import '../../domain/platform_institution_admin.dart';
import '../../domain/platform_institution_admin_create.dart';
import '../../domain/platform_institution_admin_list.dart';

class PlatformInstitutionAdminListDto {
  const PlatformInstitutionAdminListDto({
    required this.admins,
    required this.pagination,
  });

  factory PlatformInstitutionAdminListDto.fromJson(Object? json) {
    final envelope = _readRequiredMap(json, 'institution admin list envelope');
    final data = envelope['data'];
    if (data is! List<Object?>) {
      throw const FormatException(
        'Missing required institution admin list data.',
      );
    }

    return PlatformInstitutionAdminListDto(
      admins: List<PlatformInstitutionAdminDto>.unmodifiable(
        data.map(PlatformInstitutionAdminDto.fromJson),
      ),
      pagination: PlatformInstitutionAdminPaginationDto.fromJson(
        _readPagination(envelope),
      ),
    );
  }

  final List<PlatformInstitutionAdminDto> admins;
  final PlatformInstitutionAdminPaginationDto pagination;

  PlatformInstitutionAdminList toDomain() {
    return PlatformInstitutionAdminList(
      admins: List<PlatformInstitutionAdmin>.unmodifiable(
        admins.map((admin) => admin.toDomain()),
      ),
      pagination: pagination.toDomain(),
    );
  }

  static Object? _readPagination(Map<Object?, Object?> envelope) {
    final meta = _readRequiredMap(
      envelope['meta'],
      'institution admin list meta',
    );

    return meta['pagination'];
  }
}

class PlatformInstitutionAdminCreateResponseDto {
  const PlatformInstitutionAdminCreateResponseDto({
    required this.admin,
    required this.message,
  });

  factory PlatformInstitutionAdminCreateResponseDto.fromJson(Object? json) {
    final envelope = _readRequiredMap(
      json,
      'institution admin create envelope',
    );

    return PlatformInstitutionAdminCreateResponseDto(
      admin: PlatformInstitutionAdminDto.fromJson(envelope['data']),
      message: _readRequiredString(envelope, 'message'),
    );
  }

  final PlatformInstitutionAdminDto admin;
  final String message;

  PlatformInstitutionAdminCreateResult toDomain() {
    return PlatformInstitutionAdminCreateResult(
      admin: admin.toDomain(),
      message: message,
    );
  }
}

class PlatformInstitutionAdminDto {
  const PlatformInstitutionAdminDto({
    required this.id,
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

  factory PlatformInstitutionAdminDto.fromJson(Object? json) {
    final map = _readRequiredMap(json, 'institution admin resource');

    return PlatformInstitutionAdminDto(
      id: _readRequiredUuidString(map, 'id'),
      fullName: _readRequiredString(map, 'full_name'),
      loginName: _readRequiredString(map, 'login_name'),
      email: _readNullableString(map, 'email'),
      phone: _readNullableString(map, 'phone'),
      isActive: _readRequiredBool(map, 'is_active'),
      mustChangePassword: _readRequiredBool(map, 'must_change_password'),
      lastLoginAt: _readNullableRfc3339DateTime(map, 'last_login_at'),
      deactivatedAt: _readNullableRfc3339DateTime(map, 'deactivated_at'),
      createdAt: _readRequiredRfc3339DateTime(map, 'created_at'),
      updatedAt: _readRequiredRfc3339DateTime(map, 'updated_at'),
    );
  }

  final String id;
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

  PlatformInstitutionAdmin toDomain() {
    return PlatformInstitutionAdmin(
      id: id,
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

class PlatformInstitutionAdminPaginationDto {
  const PlatformInstitutionAdminPaginationDto({
    required this.page,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory PlatformInstitutionAdminPaginationDto.fromJson(Object? json) {
    final map = _readRequiredMap(json, 'institution admin list pagination');
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

    return PlatformInstitutionAdminPaginationDto(
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

  PlatformInstitutionAdminPagination toDomain() {
    return PlatformInstitutionAdminPagination(
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

String _readRequiredUuidString(Map<Object?, Object?> json, String key) {
  final value = _readRequiredString(json, key);

  if (_uuidPattern.hasMatch(value)) {
    return value;
  }

  throw FormatException('Invalid UUID field: $key.');
}

String? _readNullableString(Map<Object?, Object?> json, String key) {
  final value = json[key];

  if (value == null || value is String) {
    return value as String?;
  }

  throw FormatException('Expected nullable string field: $key.');
}

bool _readRequiredBool(Map<Object?, Object?> json, String key) {
  final value = json[key];

  if (value is bool) {
    return value;
  }

  throw FormatException('Missing required boolean field: $key.');
}

int _readRequiredNonNegativeInt(Map<Object?, Object?> json, String key) {
  final value = json[key];

  if (value is int && value >= 0) {
    return value;
  }

  throw FormatException('Missing required non-negative integer field: $key.');
}

DateTime _readRequiredRfc3339DateTime(Map<Object?, Object?> json, String key) {
  final value = _readRequiredString(json, key);
  if (!_rfc3339TimestampPattern.hasMatch(value)) {
    throw FormatException('Invalid RFC3339 timestamp field: $key.');
  }

  return DateTime.parse(value).toUtc();
}

DateTime? _readNullableRfc3339DateTime(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid nullable RFC3339 timestamp field: $key.');
  }

  if (!_rfc3339TimestampPattern.hasMatch(value)) {
    throw FormatException('Invalid nullable RFC3339 timestamp field: $key.');
  }

  return DateTime.parse(value).toUtc();
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

final _rfc3339TimestampPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
);
