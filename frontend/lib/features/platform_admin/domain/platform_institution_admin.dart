class PlatformInstitutionAdmin {
  const PlatformInstitutionAdmin({
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
}
