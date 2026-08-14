import '../../../../core/network/api_envelope.dart';
import '../../domain/institution_dashboard.dart';

class InstitutionDashboardDto {
  const InstitutionDashboardDto({
    required this.teachers,
    required this.students,
    required this.parents,
  });

  factory InstitutionDashboardDto.fromJson(Object? json) {
    return ApiSuccessEnvelope.fromJson(json, (data) {
      final dataMap = _readRequiredMap(data, 'institution dashboard');
      final usersMap = _readRequiredMap(dataMap['users'], 'dashboard users');

      return InstitutionDashboardDto(
        teachers: _readRequiredNonNegativeInt(usersMap, 'teachers'),
        students: _readRequiredNonNegativeInt(usersMap, 'students'),
        parents: _readRequiredNonNegativeInt(usersMap, 'parents'),
      );
    }).data;
  }

  final int teachers;
  final int students;
  final int parents;

  InstitutionDashboard toDomain() {
    return InstitutionDashboard(
      teachers: teachers,
      students: students,
      parents: parents,
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

int _readRequiredNonNegativeInt(Map<Object?, Object?> json, String key) {
  final value = json[key];

  if (value is int && value >= 0) {
    return value;
  }

  throw FormatException('Missing required non-negative integer field: $key.');
}
