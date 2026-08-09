import 'auth_institution.dart';
import 'user_role.dart';

class AuthUser {
  const AuthUser({
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

  final String id;
  final String? institutionId;
  final UserRole role;
  final String fullName;
  final String loginName;
  final String? email;
  final String? phone;
  final bool isActive;
  final bool mustChangePassword;
  final AuthInstitution? institution;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthUser &&
            other.id == id &&
            other.institutionId == institutionId &&
            other.role == role &&
            other.fullName == fullName &&
            other.loginName == loginName &&
            other.email == email &&
            other.phone == phone &&
            other.isActive == isActive &&
            other.mustChangePassword == mustChangePassword &&
            other.institution == institution;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      institutionId,
      role,
      fullName,
      loginName,
      email,
      phone,
      isActive,
      mustChangePassword,
      institution,
    );
  }
}
