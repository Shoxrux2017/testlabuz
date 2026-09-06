final canonicalTeacherGroupIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isCanonicalTeacherGroupId(String value) {
  return canonicalTeacherGroupIdPattern.hasMatch(value);
}

class TeacherGroupStudent {
  const TeacherGroupStudent({
    required this.id,
    required this.fullName,
    required this.loginName,
  });

  final String id;
  final String fullName;
  final String loginName;
}
