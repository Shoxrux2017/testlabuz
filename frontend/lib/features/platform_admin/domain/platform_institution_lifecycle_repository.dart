import 'platform_institution_lifecycle.dart';

abstract interface class PlatformInstitutionLifecycleRepository {
  Future<PlatformInstitutionLifecycleResult> activateInstitution(
    String institutionId,
  );

  Future<PlatformInstitutionLifecycleResult> deactivateInstitution(
    String institutionId,
  );
}

class PlatformInstitutionLifecycleOutcomeUnknownException implements Exception {
  const PlatformInstitutionLifecycleOutcomeUnknownException(this.message);

  final String message;

  @override
  String toString() {
    return 'PlatformInstitutionLifecycleOutcomeUnknownException: $message';
  }
}
