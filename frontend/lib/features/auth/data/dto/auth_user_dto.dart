import '../../domain/auth_user.dart';
import '../../domain/user_role.dart';
import 'auth_dto_parse.dart';
import 'auth_institution_dto.dart';

class AuthUserDto {
  const AuthUserDto({
    required this.id,
    required this.institutionId,
    required this.role,
    required this.fullName,
    required this.loginName,
    required this.email,
    required this.phone,
    required this.isActive,
    required this.mustChangePassword,
    required this.institution,
  });

  factory AuthUserDto.fromJson(
    Object? json, {
    required bool requireInstitutionContext,
  }) {
    final map = readRequiredMap(json, 'auth user');
    final role = UserRole.parse(readRequiredString(map, 'role'));
    final institutionId = readNullableString(map, 'institution_id');
    final rawInstitution = map['institution'];

    AuthInstitutionDto? institution;
    if (rawInstitution != null) {
      institution = AuthInstitutionDto.fromJson(rawInstitution);
    }

    if (role == UserRole.platformOwner) {
      if (institutionId != null || institution != null) {
        throw const FormatException(
          'Platform owner session must not include institution identity.',
        );
      }
    } else {
      if (institutionId == null) {
        throw const FormatException(
          'Institution user session requires institution_id.',
        );
      }

      if (requireInstitutionContext && institution == null) {
        throw const FormatException(
          'Institution user session requires institution context.',
        );
      }
    }

    return AuthUserDto(
      id: readRequiredString(map, 'id'),
      institutionId: institutionId,
      role: role,
      fullName: readRequiredString(map, 'full_name'),
      loginName: readRequiredString(map, 'login_name'),
      email: readNullableString(map, 'email'),
      phone: readNullableString(map, 'phone'),
      isActive: readRequiredBool(map, 'is_active'),
      mustChangePassword: readRequiredBool(map, 'must_change_password'),
      institution: institution,
    );
  }

  final String id;
  final String? institutionId;
  final UserRole role;
  final String fullName;
  final String loginName;
  final String? email;
  final String? phone;
  final bool isActive;
  final bool mustChangePassword;
  final AuthInstitutionDto? institution;

  AuthUser toDomain() {
    return AuthUser(
      id: id,
      institutionId: institutionId,
      role: role,
      fullName: fullName,
      loginName: loginName,
      email: email,
      phone: phone,
      isActive: isActive,
      mustChangePassword: mustChangePassword,
      institution: institution?.toDomain(),
    );
  }
}
