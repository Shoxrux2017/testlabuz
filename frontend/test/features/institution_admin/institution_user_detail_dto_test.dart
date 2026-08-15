import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_user_detail_dto.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_user_dto.dart';

void main() {
  test(
    'accepts the exact data-only envelope and delegates the shared parser',
    () {
      final dto = InstitutionUserDetailDto.fromJson(_envelope());

      expect(dto.user, isA<InstitutionUserDto>());
      expect(dto.user.id, _userId);
      expect(dto.user.fullName, 'Teacher Name');
      expect(dto.user.email, 'teacher@example.uz');
      expect(dto.user.lastLoginAt, DateTime.utc(2026, 8, 7, 15));
    },
  );

  test('rejects missing, extra, and protected envelope keys', () {
    expect(
      () => InstitutionUserDetailDto.fromJson(
        {'data': _resource()}..remove('data'),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => InstitutionUserDetailDto.fromJson({
        'data': _resource(),
        'meta': <String, Object?>{},
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => InstitutionUserDetailDto.fromJson({
        'data': {..._resource(), 'institution_id': 'private'},
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('preserves strict shared User validation', () {
    for (final invalidResource in [
      {..._resource(), 'role': 'institution_admin'},
      {..._resource(), 'id': 'not-a-uuid'},
      {..._resource(), 'is_active': 'true'},
      {..._resource(), 'created_at': '2026-08-07T15:00:00+05:00'},
      {..._resource(), 'is_active': false, 'deactivated_at': null},
    ]) {
      expect(
        () => InstitutionUserDetailDto.fromJson({'data': invalidResource}),
        throwsA(isA<FormatException>()),
      );
    }
  });
}

const _userId = '550e8400-e29b-41d4-a716-446655440000';

Map<String, Object?> _envelope() => {'data': _resource()};

Map<String, Object?> _resource() => {
  'id': _userId,
  'role': 'teacher',
  'full_name': 'Teacher Name',
  'login_name': 'teacher01',
  'email': 'teacher@example.uz',
  'phone': '+998901234567',
  'is_active': true,
  'must_change_password': false,
  'last_login_at': '2026-08-07T15:00:00Z',
  'deactivated_at': null,
  'created_at': '2026-08-07T14:00:00Z',
  'updated_at': '2026-08-07T16:00:00Z',
};
