import 'institution_profile.dart';
import 'institution_profile_update.dart';

abstract interface class InstitutionProfileRepository {
  Future<InstitutionProfile> fetchProfile();

  Future<InstitutionProfileUpdateResult> updateProfile(
    InstitutionProfileUpdateRequest request,
  );
}

class InstitutionProfileUpdateOutcomeUnknownException implements Exception {
  const InstitutionProfileUpdateOutcomeUnknownException();

  @override
  String toString() => 'Institution profile update outcome is unknown.';
}
