import 'platform_institution_admin.dart';

enum PlatformInstitutionAdminLifecycleAction {
  activate,
  deactivate;

  bool get targetIsActive {
    return switch (this) {
      PlatformInstitutionAdminLifecycleAction.activate => true,
      PlatformInstitutionAdminLifecycleAction.deactivate => false,
    };
  }

  String get endpointSegment {
    return switch (this) {
      PlatformInstitutionAdminLifecycleAction.activate => 'activate',
      PlatformInstitutionAdminLifecycleAction.deactivate => 'deactivate',
    };
  }

  String get confirmLabel {
    return switch (this) {
      PlatformInstitutionAdminLifecycleAction.activate => 'Activate',
      PlatformInstitutionAdminLifecycleAction.deactivate => 'Deactivate',
    };
  }

  String get title {
    return switch (this) {
      PlatformInstitutionAdminLifecycleAction.activate =>
        'Activate administrator',
      PlatformInstitutionAdminLifecycleAction.deactivate =>
        'Deactivate administrator',
    };
  }

  String get successMessage {
    return switch (this) {
      PlatformInstitutionAdminLifecycleAction.activate =>
        'Institution admin activated successfully.',
      PlatformInstitutionAdminLifecycleAction.deactivate =>
        'Institution admin deactivated successfully.',
    };
  }

  static PlatformInstitutionAdminLifecycleAction forAdmin(
    PlatformInstitutionAdmin admin,
  ) {
    return admin.isActive
        ? PlatformInstitutionAdminLifecycleAction.deactivate
        : PlatformInstitutionAdminLifecycleAction.activate;
  }
}

class PlatformInstitutionAdminLifecycleResult {
  const PlatformInstitutionAdminLifecycleResult({
    required this.admin,
    required this.message,
    required this.action,
  });

  final PlatformInstitutionAdmin admin;
  final String message;
  final PlatformInstitutionAdminLifecycleAction action;
}
