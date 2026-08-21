enum InstitutionGroupStatus {
  active('active'),
  archived('archived');

  const InstitutionGroupStatus(this.value);

  final String value;

  static InstitutionGroupStatus parse(String value) {
    return switch (value) {
      'active' => InstitutionGroupStatus.active,
      'archived' => InstitutionGroupStatus.archived,
      _ => throw FormatException('Unsupported Institution Group status.'),
    };
  }
}

class InstitutionGroup {
  const InstitutionGroup({
    required this.id,
    required this.name,
    required this.level,
    required this.subjectDirection,
    required this.description,
    required this.status,
    required this.teachersCount,
    required this.studentsCount,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? level;
  final String? subjectDirection;
  final String? description;
  final InstitutionGroupStatus status;
  final int teachersCount;
  final int studentsCount;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
