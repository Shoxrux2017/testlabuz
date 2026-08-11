import 'platform_institution.dart';

class PlatformInstitutionDetail {
  const PlatformInstitutionDetail({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.contactEmail,
    required this.contactPhone,
    required this.address,
    required this.description,
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
  final String? address;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PlatformInstitutionUserCounts userCounts;
}
