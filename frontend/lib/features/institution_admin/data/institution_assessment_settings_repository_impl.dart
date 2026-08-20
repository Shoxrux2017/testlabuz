import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/institution_assessment_settings.dart';
import '../domain/institution_assessment_settings_repository.dart';
import 'institution_assessment_settings_remote_data_source.dart';

final institutionAssessmentSettingsRepositoryProvider =
    Provider<InstitutionAssessmentSettingsRepository>((ref) {
      return InstitutionAssessmentSettingsRepositoryImpl(
        remoteDataSource: ref.watch(
          institutionAssessmentSettingsRemoteDataSourceProvider,
        ),
      );
    });

class InstitutionAssessmentSettingsRepositoryImpl
    implements InstitutionAssessmentSettingsRepository {
  const InstitutionAssessmentSettingsRepositoryImpl({
    required this.remoteDataSource,
  });

  final InstitutionAssessmentSettingsRemoteDataSource remoteDataSource;

  @override
  Future<InstitutionAssessmentSettings> fetchSettings() async {
    final dto = await remoteDataSource.fetchSettings();
    return dto.settings;
  }

  @override
  Future<InstitutionAssessmentSettings> updateSettings(
    InstitutionAssessmentSettingsUpdateRequest request,
  ) async {
    final dto = await remoteDataSource.updateSettings(request);
    return dto.settings;
  }
}
