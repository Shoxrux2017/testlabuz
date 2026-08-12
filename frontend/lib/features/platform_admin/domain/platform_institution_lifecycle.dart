import 'platform_institution.dart';

class PlatformInstitutionLifecycleResult {
  const PlatformInstitutionLifecycleResult({
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
    required this.message,
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
  final String message;
}

enum PlatformInstitutionLifecycleAction {
  activate,
  deactivate;

  PlatformInstitutionStatus get targetStatus {
    return switch (this) {
      PlatformInstitutionLifecycleAction.activate =>
        PlatformInstitutionStatus.active,
      PlatformInstitutionLifecycleAction.deactivate =>
        PlatformInstitutionStatus.inactive,
    };
  }

  String get endpointSegment {
    return switch (this) {
      PlatformInstitutionLifecycleAction.activate => 'activate',
      PlatformInstitutionLifecycleAction.deactivate => 'deactivate',
    };
  }

  String get confirmLabel {
    return switch (this) {
      PlatformInstitutionLifecycleAction.activate => 'Activate',
      PlatformInstitutionLifecycleAction.deactivate => 'Deactivate',
    };
  }

  String get title {
    return switch (this) {
      PlatformInstitutionLifecycleAction.activate => 'Activate institution',
      PlatformInstitutionLifecycleAction.deactivate => 'Deactivate institution',
    };
  }

  static PlatformInstitutionLifecycleAction forSourceStatus(
    PlatformInstitutionStatus status,
  ) {
    return switch (status) {
      PlatformInstitutionStatus.active =>
        PlatformInstitutionLifecycleAction.deactivate,
      PlatformInstitutionStatus.inactive =>
        PlatformInstitutionLifecycleAction.activate,
    };
  }
}
