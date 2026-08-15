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

  test('rejects every non-data-only or wrong-type detail envelope', () {
    final invalidEnvelopes = <Object?>[
      null,
      <Object?>[],
      <String, Object?>{},
      {'data': null},
      {'data': <Object?>[]},
      {'data': _resource(), 'message': 'Unexpected success message.'},
      {'data': _resource(), 'meta': <String, Object?>{}},
      {'data': _resource(), 'links': <String, Object?>{}},
    ];

    for (final envelope in invalidEnvelopes) {
      expect(
        () => InstitutionUserDetailDto.fromJson(envelope),
        throwsA(isA<FormatException>()),
        reason: '$envelope',
      );
    }
  });

  test('rejects missing, unknown, and protected shared resource keys', () {
    for (final key in _resource().keys) {
      final missing = _resource()..remove(key);
      expect(
        () => InstitutionUserDetailDto.fromJson({'data': missing}),
        throwsA(isA<FormatException>()),
        reason: 'missing $key',
      );
    }

    for (final protectedKey in const [
      'institution_id',
      'created_by_user_id',
      'creator',
      'password',
      'remember_token',
      'tokens',
      'permissions',
      'relationships',
      'settings',
      'scores',
      'results',
    ]) {
      expect(
        () => InstitutionUserDetailDto.fromJson({
          'data': {..._resource(), protectedKey: 'private'},
        }),
        throwsA(isA<FormatException>()),
        reason: protectedKey,
      );
    }
  });

  test('preserves the complete strict shared User validation matrix', () {
    final invalidResources = <Map<String, Object?>>[
      _resource(overrides: {'id': 'not-a-uuid'}),
      _resource(overrides: {'role': 'institution_admin'}),
      _resource(overrides: {'role': 'Teacher'}),
      _resource(overrides: {'full_name': '   '}),
      _resource(overrides: {'login_name': 42}),
      _resource(overrides: {'email': false}),
      _resource(overrides: {'phone': <Object?>[]}),
      _resource(overrides: {'is_active': 'true'}),
      _resource(overrides: {'must_change_password': 1}),
      _resource(overrides: {'last_login_at': '2026-08-07T15:00:00+05:00'}),
      _resource(overrides: {'last_login_at': 'not-a-time'}),
      _resource(overrides: {'created_at': null}),
      _resource(overrides: {'created_at': '2026-08-07T15:00:00+05:00'}),
      _resource(overrides: {'updated_at': 1}),
      _resource(
        overrides: {
          'is_active': true,
          'deactivated_at': '2026-08-07T15:00:00Z',
        },
      ),
      _resource(overrides: {'is_active': false, 'deactivated_at': null}),
    ];

    for (final invalidResource in invalidResources) {
      expect(
        () => InstitutionUserDetailDto.fromJson({'data': invalidResource}),
        throwsA(isA<FormatException>()),
        reason: '$invalidResource',
      );
    }
  });

  test('accepts an exact inactive resource with nullable contacts', () {
    final dto = InstitutionUserDetailDto.fromJson({
      'data': _resource(
        overrides: {
          'role': 'parent',
          'email': null,
          'phone': null,
          'is_active': false,
          'last_login_at': null,
          'deactivated_at': '2026-08-08T15:00:00Z',
        },
      ),
    });

    expect(dto.user.role.value, 'parent');
    expect(dto.user.email, isNull);
    expect(dto.user.phone, isNull);
    expect(dto.user.isActive, isFalse);
    expect(dto.user.deactivatedAt, DateTime.utc(2026, 8, 8, 15));
  });
}

const _userId = '550e8400-e29b-41d4-a716-446655440000';

Map<String, Object?> _envelope() => {'data': _resource()};

Map<String, Object?> _resource({Map<String, Object?> overrides = const {}}) => {
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
  ...overrides,
};
