import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/institution_admin/data/dto/institution_user_create_dto.dart';

void main() {
  test(
    'accepts only the exact create success envelope and shared resource',
    () {
      final dto = InstitutionUserCreateDto.fromJson({
        'data': _resource(),
        'message': InstitutionUserCreateDto.successMessage,
      });

      expect(dto.user.id, _userId);
      expect(dto.user.mustChangePassword, isTrue);
    },
  );

  test('rejects missing, extra, or wrong success envelope members', () {
    final invalid = <Object?>[
      null,
      {'data': _resource()},
      {'data': _resource(), 'message': 'Different message.'},
      {
        'data': _resource(),
        'message': InstitutionUserCreateDto.successMessage,
        'meta': <String, Object?>{},
      },
      {
        'data': {..._resource(), 'password': 'private'},
        'message': InstitutionUserCreateDto.successMessage,
      },
    ];

    for (final body in invalid) {
      expect(
        () => InstitutionUserCreateDto.fromJson(body),
        throwsA(isA<FormatException>()),
        reason: '$body',
      );
    }
  });

  test(
    'accepts all three creatable roles and nullable/contact combinations',
    () {
      final cases = <({String role, String? email, String? phone})>[
        (role: 'teacher', email: null, phone: null),
        (role: 'student', email: 'student@example.uz', phone: null),
        (role: 'parent', email: null, phone: '+998901234567'),
      ];

      for (final value in cases) {
        final dto = InstitutionUserCreateDto.fromJson({
          'data': {
            ..._resource(),
            'role': value.role,
            'email': value.email,
            'phone': value.phone,
          },
          'message': InstitutionUserCreateDto.successMessage,
        });
        expect(dto.user.role.value, value.role);
        expect(dto.user.email, value.email);
        expect(dto.user.phone, value.phone);
      }
    },
  );
}

const _userId = '00000000-0000-0000-0000-000000000001';

Map<String, Object?> _resource() => {
  'id': _userId,
  'role': 'teacher',
  'full_name': 'Teacher Name',
  'login_name': 'teacher01',
  'email': null,
  'phone': null,
  'is_active': true,
  'must_change_password': true,
  'last_login_at': null,
  'deactivated_at': null,
  'created_at': '2026-08-15T08:00:00Z',
  'updated_at': '2026-08-15T08:00:00Z',
};
