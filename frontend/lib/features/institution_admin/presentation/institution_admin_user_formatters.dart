import '../domain/institution_user.dart';

String formatInstitutionUserRole(InstitutionUserRole role) {
  return switch (role) {
    InstitutionUserRole.teacher => 'Teacher',
    InstitutionUserRole.student => 'Student',
    InstitutionUserRole.parent => 'Parent',
  };
}

String formatInstitutionUserUtc(DateTime value) {
  final utc = value.toUtc();

  return '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')} '
      '${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')} UTC';
}
