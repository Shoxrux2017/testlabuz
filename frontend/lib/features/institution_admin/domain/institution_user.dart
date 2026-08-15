enum InstitutionUserRole {
  teacher('teacher'),
  student('student'),
  parent('parent');

  const InstitutionUserRole(this.value);

  final String value;

  static InstitutionUserRole parse(String value) {
    for (final role in values) {
      if (role.value == value) {
        return role;
      }
    }

    throw const FormatException('Unsupported Institution User role.');
  }
}

class InstitutionUser {
  const InstitutionUser({
    required this.id,
    required this.role,
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

  final String id;
  final InstitutionUserRole role;
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
}
