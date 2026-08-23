final canonicalStudentTopicIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isCanonicalStudentTopicId(String value) {
  return canonicalStudentTopicIdPattern.hasMatch(value);
}

enum StudentTopicStatus {
  active('active'),
  closed('closed'),
  archived('archived');

  const StudentTopicStatus(this.value);

  final String value;

  static StudentTopicStatus parse(String value) {
    return switch (value) {
      'active' => StudentTopicStatus.active,
      'closed' => StudentTopicStatus.closed,
      'archived' => StudentTopicStatus.archived,
      _ => throw const FormatException('Unsupported Student Topic status.'),
    };
  }
}

enum StudentGroupStatus {
  active('active'),
  archived('archived');

  const StudentGroupStatus(this.value);

  final String value;

  static StudentGroupStatus parse(String value) {
    return switch (value) {
      'active' => StudentGroupStatus.active,
      'archived' => StudentGroupStatus.archived,
      _ => throw const FormatException('Unsupported Student Group status.'),
    };
  }
}

class StudentGroupSummary {
  const StudentGroupSummary({
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
  final StudentGroupStatus status;
}

class StudentLearningMaterialFile {
  const StudentLearningMaterialFile({
    required this.id,
    required this.originalName,
    required this.extension,
    required this.sizeBytes,
  });

  final String id;
  final String originalName;
  final String extension;
  final int sizeBytes;
}

class StudentLearningMaterial {
  const StudentLearningMaterial({
    required this.id,
    required this.title,
    required this.file,
  });

  final String id;
  final String? title;
  final StudentLearningMaterialFile file;

  String get displayName => title ?? file.originalName;
}

class StudentTopicSummary {
  const StudentTopicSummary({
    required this.id,
    required this.group,
    required this.title,
    required this.subject,
    required this.lessonAt,
    required this.status,
  });

  final String id;
  final StudentGroupSummary group;
  final String title;
  final String subject;
  final DateTime? lessonAt;
  final StudentTopicStatus status;
}

class StudentTopicDetail {
  StudentTopicDetail({
    required this.id,
    required this.group,
    required this.title,
    required this.description,
    required this.subject,
    required this.studentInstructions,
    required this.lessonAt,
    required this.status,
    required List<StudentLearningMaterial> materials,
  }) : materials = List<StudentLearningMaterial>.unmodifiable(materials);

  final String id;
  final StudentGroupSummary group;
  final String title;
  final String? description;
  final String subject;
  final String studentInstructions;
  final DateTime? lessonAt;
  final StudentTopicStatus status;
  final List<StudentLearningMaterial> materials;

  StudentLearningMaterial? materialById(String materialId) {
    for (final material in materials) {
      if (material.id.toLowerCase() == materialId.toLowerCase()) {
        return material;
      }
    }
    return null;
  }
}
