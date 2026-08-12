import 'platform_institution_create.dart';

abstract interface class PlatformInstitutionCreateRepository {
  Future<PlatformInstitutionCreateResult> createInstitution(
    PlatformInstitutionCreateRequest request,
  );
}

class PlatformInstitutionCreateOutcomeUnknownException implements Exception {
  const PlatformInstitutionCreateOutcomeUnknownException(this.message);

  final String message;

  @override
  String toString() {
    return 'PlatformInstitutionCreateOutcomeUnknownException: $message';
  }
}
