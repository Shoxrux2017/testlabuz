class PlatformInstitutionSummary {
  const PlatformInstitutionSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.contactEmail,
    required this.contactPhone,
    required this.createdAt,
    required this.updatedAt,
    required this.userCounts,
  });

  final String id;
  final String name;
  final PlatformInstitutionType type;
  final PlatformInstitutionStatus status;
  final String? contactEmail;
  final String? contactPhone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PlatformInstitutionUserCounts userCounts;
}

class PlatformInstitutionUserCounts {
  const PlatformInstitutionUserCounts({
    required this.total,
    required this.active,
  });

  final int total;
  final int active;
}

enum PlatformInstitutionType {
  school('school'),
  college('college'),
  lyceum('lyceum'),
  university('university'),
  institute('institute'),
  learningCenter('learning_center'),
  trainingCenter('training_center'),
  privateEducation('private_education'),
  other('other');

  const PlatformInstitutionType(this.value);

  final String value;

  static PlatformInstitutionType parse(String value) {
    for (final type in values) {
      if (type.value == value) {
        return type;
      }
    }

    throw FormatException('Unknown institution type: $value');
  }
}

enum PlatformInstitutionStatus {
  active('active'),
  inactive('inactive');

  const PlatformInstitutionStatus(this.value);

  final String value;

  static PlatformInstitutionStatus parse(String value) {
    for (final status in values) {
      if (status.value == value) {
        return status;
      }
    }

    throw FormatException('Unknown institution status: $value');
  }
}
