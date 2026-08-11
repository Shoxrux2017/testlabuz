import 'platform_institution.dart';

export 'platform_institution.dart';

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
