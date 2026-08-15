import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_user_list_dto.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_list_query.dart';

void main() {
  test('Institution User DTO preserves exact nullable public values', () {
    final page = InstitutionUserListDto.fromJson({
      'data': [
        {
          'id': '00000000-0000-0000-0000-000000000001',
          'role': 'student',
          'full_name': 'Student Name',
          'login_name': 'student01',
          'email': null,
          'phone': '',
          'is_active': true,
          'must_change_password': false,
          'last_login_at': '2026-08-07T15:00:00Z',
          'deactivated_at': null,
          'created_at': '2026-08-07T14:00:00Z',
          'updated_at': '2026-08-07T16:00:00Z',
        },
      ],
      'meta': {
        'pagination': {'page': 1, 'per_page': 20, 'total': 1, 'last_page': 1},
      },
    }, requestedQuery: const InstitutionUserListQuery.initial()).toDomain();

    expect(page.users.single.email, isNull);
    expect(page.users.single.phone, '');
    expect(page.users.single.lastLoginAt, DateTime.utc(2026, 8, 7, 15));
    expect(page.pagination.total, 1);
  });
}
