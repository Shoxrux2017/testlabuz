import '../domain/institution_profile.dart';

String formatInstitutionProfileType(InstitutionProfileType type) {
  return switch (type) {
    InstitutionProfileType.school => 'School',
    InstitutionProfileType.college => 'College',
    InstitutionProfileType.lyceum => 'Lyceum',
    InstitutionProfileType.university => 'University',
    InstitutionProfileType.institute => 'Institute',
    InstitutionProfileType.learningCenter => 'Learning center',
    InstitutionProfileType.trainingCenter => 'Training center',
    InstitutionProfileType.privateEducation => 'Private education',
    InstitutionProfileType.other => 'Other',
  };
}

String formatInstitutionProfileStatus(InstitutionProfileStatus status) {
  return switch (status) {
    InstitutionProfileStatus.active => 'Active',
    InstitutionProfileStatus.inactive => 'Inactive',
  };
}

String formatInstitutionProfileOptional(String? value) {
  return value ?? 'Not provided';
}

String formatInstitutionProfileUtc(DateTime value) {
  final utc = value.toUtc();

  return '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')} '
      '${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')} UTC';
}
