import 'institution_assessment_settings.dart';

abstract interface class InstitutionAssessmentSettingsRepository {
  Future<InstitutionAssessmentSettings> fetchSettings();

  Future<InstitutionAssessmentSettings> updateSettings(
    InstitutionAssessmentSettingsUpdateRequest request,
  );
}

class InstitutionAssessmentSettingsUpdateOutcomeUnknownException
    implements Exception {
  const InstitutionAssessmentSettingsUpdateOutcomeUnknownException();
}
