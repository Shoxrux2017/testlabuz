import '../../domain/auth_institution.dart';
import 'auth_dto_parse.dart';

class AuthInstitutionDto {
  const AuthInstitutionDto({
    required this.id,
    required this.name,
    required this.status,
    required this.timezone,
  });

  factory AuthInstitutionDto.fromJson(Object? json) {
    final map = readRequiredMap(json, 'auth institution');

    return AuthInstitutionDto(
      id: readRequiredString(map, 'id'),
      name: readRequiredString(map, 'name'),
      status: readRequiredString(map, 'status'),
      timezone: readRequiredString(map, 'timezone'),
    );
  }

  final String id;
  final String name;
  final String status;
  final String timezone;

  AuthInstitution toDomain() {
    return AuthInstitution(
      id: id,
      name: name,
      status: status,
      timezone: timezone,
    );
  }
}
