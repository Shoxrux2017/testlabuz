import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_profile.dart';
import 'package:testlabuz_client/features/institution_admin/presentation/institution_profile_formatters.dart';

void main() {
  test('formats every exact type and status label', () {
    expect(InstitutionProfileType.values.map(formatInstitutionProfileType), [
      'School',
      'College',
      'Lyceum',
      'University',
      'Institute',
      'Learning center',
      'Training center',
      'Private education',
      'Other',
    ]);
    expect(
      InstitutionProfileStatus.values.map(formatInstitutionProfileStatus),
      ['Active', 'Inactive'],
    );
  });

  test('formats null and UTC timestamps exactly', () {
    expect(formatInstitutionProfileOptional(null), 'Not provided');
    expect(formatInstitutionProfileOptional(''), '');
    expect(
      formatInstitutionProfileUtc(DateTime.parse('2026-08-07T20:00:00+05:00')),
      '2026-08-07 15:00 UTC',
    );
  });
}
