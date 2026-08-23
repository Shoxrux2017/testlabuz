enum TeacherGroupStatus {
  active('active'),
  archived('archived');

  const TeacherGroupStatus(this.value);

  final String value;

  static TeacherGroupStatus parse(String value) {
    return switch (value) {
      'active' => TeacherGroupStatus.active,
      'archived' => TeacherGroupStatus.archived,
      _ => throw const FormatException('Unsupported Teacher Group status.'),
    };
  }
}

class TeacherGroupSummary {
  const TeacherGroupSummary({
    required this.id,
    required this.name,
    required this.level,
    required this.subjectDirection,
    required this.status,
  });

  final String id;
  final String name;
  final String? level;
  final String? subjectDirection;
  final TeacherGroupStatus status;
}
