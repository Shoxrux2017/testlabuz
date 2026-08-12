import 'platform_institution_edit.dart';

abstract interface class PlatformInstitutionEditRepository {
  Future<PlatformInstitutionEditResult> updateInstitution(
    String institutionId,
    PlatformInstitutionEditRequest request,
  );
}

class PlatformInstitutionEditOutcomeUnknownException implements Exception {
  const PlatformInstitutionEditOutcomeUnknownException(this.message);

  final String message;

  @override
  String toString() {
    return 'PlatformInstitutionEditOutcomeUnknownException: $message';
  }
}
