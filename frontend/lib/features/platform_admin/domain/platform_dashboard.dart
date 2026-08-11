class PlatformDashboard {
  const PlatformDashboard({
    required this.institutions,
    required this.users,
    required this.recentInstitutions,
  });

  final PlatformInstitutionCounts institutions;
  final PlatformUserCounts users;
  final List<RecentPlatformInstitution> recentInstitutions;

  bool get isInstitutionEmpty {
    return institutions.total == 0 &&
        institutions.active == 0 &&
        institutions.inactive == 0 &&
        recentInstitutions.isEmpty;
  }
}

class PlatformInstitutionCounts {
  const PlatformInstitutionCounts({
    required this.total,
    required this.active,
    required this.inactive,
  });

  final int total;
  final int active;
  final int inactive;
}

class PlatformUserCounts {
  const PlatformUserCounts({required this.total, required this.active});

  final int total;
  final int active;
}

class RecentPlatformInstitution {
  const RecentPlatformInstitution({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String name;
  final PlatformInstitutionType type;
  final PlatformInstitutionStatus status;
  final DateTime createdAt;
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
