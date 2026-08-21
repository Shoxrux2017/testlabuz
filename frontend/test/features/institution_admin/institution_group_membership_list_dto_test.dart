import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_group_membership_list_dto.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_group_membership_query.dart';

import 'institution_group_test_support.dart';

void main() {
  test('parses exact envelope and pagination', () {
    const query = InstitutionGroupMembershipQuery.initial();
    final page = InstitutionGroupMembershipListDto.fromJson({
      'data': [membershipResource()],
      'meta': {
        'pagination': {'page': 1, 'per_page': 20, 'total': 1, 'last_page': 1},
      },
    }, requestedQuery: query).toDomain();
    expect(page.memberships.single.id, testTeacherId);
    expect(page.pagination.total, 1);
  });

  test('rejects case-insensitive duplicates and pagination contradictions', () {
    const query = InstitutionGroupMembershipQuery.initial();
    expect(
      () => InstitutionGroupMembershipListDto.fromJson({
        'data': [
          membershipResource(id: testGroupIdUpper),
          membershipResource(id: testGroupIdUpper.toLowerCase()),
        ],
        'meta': {
          'pagination': {'page': 1, 'per_page': 20, 'total': 2, 'last_page': 1},
        },
      }, requestedQuery: query),
      throwsFormatException,
    );
    for (final pagination in <Map<String, Object?>>[
      {'page': '1', 'per_page': 20, 'total': 0, 'last_page': 1},
      {'page': 2, 'per_page': 20, 'total': 0, 'last_page': 1},
      {'page': 1, 'per_page': 50, 'total': 0, 'last_page': 1},
      {'page': 1, 'per_page': 20, 'total': 21, 'last_page': 1},
    ]) {
      expect(
        () => InstitutionGroupMembershipListDto.fromJson({
          'data': <Object?>[],
          'meta': {'pagination': pagination},
        }, requestedQuery: query),
        throwsFormatException,
      );
    }
  });

  test('rejects unknown or renamed envelope keys', () {
    const query = InstitutionGroupMembershipQuery.initial();
    expect(
      () => InstitutionGroupMembershipListDto.fromJson({
        'data': <Object?>[],
        'meta': {
          'pagination': {
            'current_page': 1,
            'per_page': 20,
            'total': 0,
            'last_page': 1,
          },
        },
      }, requestedQuery: query),
      throwsFormatException,
    );
  });
}
