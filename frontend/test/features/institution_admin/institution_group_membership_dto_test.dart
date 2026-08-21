import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_group_membership_dto.dart';

import 'institution_group_test_support.dart';

void main() {
  test('parses exact active and inactive resources with nullable contact', () {
    final active = InstitutionGroupMembershipDto.fromJson(
      membershipResource(),
    ).toDomain();
    expect(active.id, testTeacherId);
    expect(active.isActive, isTrue);
    expect(active.startedAt, DateTime.utc(2026, 8, 21, 10, 15));

    final inactive = InstitutionGroupMembershipDto.fromJson(
      membershipResource(
        id: testStudentId,
        email: null,
        phone: null,
        isActive: false,
      ),
    ).toDomain();
    expect(inactive.email, isNull);
    expect(inactive.phone, isNull);
    expect(inactive.isActive, isFalse);
  });

  test(
    'rejects missing unknown wrong types malformed UUID and non-UTC time',
    () {
      final invalid = <Map<String, Object?>>[
        {...membershipResource()}..remove('login_name'),
        {...membershipResource(), 'extra': true},
        {...membershipResource(), 'is_active': 1},
        membershipResource(id: 'not-a-uuid'),
        membershipResource(startedAt: '2026-08-21T10:15:00+05:00'),
        membershipResource(startedAt: '2026-02-31T10:15:00Z'),
        membershipResource(fullName: '   '),
      ];
      for (final resource in invalid) {
        expect(
          () => InstitutionGroupMembershipDto.fromJson(resource),
          throwsFormatException,
        );
      }
    },
  );
}
