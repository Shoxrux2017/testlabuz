enum UserRole {
  platformOwner('platform_owner'),
  institutionAdmin('institution_admin'),
  teacher('teacher'),
  student('student'),
  parent('parent');

  const UserRole(this.value);

  final String value;

  static UserRole parse(String value) {
    for (final role in values) {
      if (role.value == value) {
        return role;
      }
    }

    throw FormatException('Unknown user role: $value');
  }
}
