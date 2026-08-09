class AuthInstitution {
  const AuthInstitution({
    required this.id,
    required this.name,
    required this.status,
    required this.timezone,
  });

  final String id;
  final String name;
  final String status;
  final String timezone;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthInstitution &&
            other.id == id &&
            other.name == name &&
            other.status == status &&
            other.timezone == timezone;
  }

  @override
  int get hashCode => Object.hash(id, name, status, timezone);
}
