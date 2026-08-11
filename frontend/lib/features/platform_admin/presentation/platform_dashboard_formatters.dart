import '../domain/platform_dashboard.dart';

String platformInstitutionTypeLabel(PlatformInstitutionType type) {
  return switch (type) {
    PlatformInstitutionType.school => 'School',
    PlatformInstitutionType.college => 'College',
    PlatformInstitutionType.lyceum => 'Lyceum',
    PlatformInstitutionType.university => 'University',
    PlatformInstitutionType.institute => 'Institute',
    PlatformInstitutionType.learningCenter => 'Learning center',
    PlatformInstitutionType.trainingCenter => 'Training center',
    PlatformInstitutionType.privateEducation => 'Private education',
    PlatformInstitutionType.other => 'Other',
  };
}

String platformInstitutionStatusLabel(PlatformInstitutionStatus status) {
  return switch (status) {
    PlatformInstitutionStatus.active => 'Active',
    PlatformInstitutionStatus.inactive => 'Inactive',
  };
}

String formatPlatformDashboardUtcTimestamp(DateTime timestamp) {
  final utc = timestamp.toUtc();

  return '${_fourDigits(utc.year)}-${_twoDigits(utc.month)}-${_twoDigits(utc.day)} '
      '${_twoDigits(utc.hour)}:${_twoDigits(utc.minute)} UTC';
}

String _fourDigits(int value) {
  return value.toString().padLeft(4, '0');
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}
