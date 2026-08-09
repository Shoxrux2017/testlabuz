import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/auth/data/dto/auth_institution_dto.dart';
import 'package:testlabuz_client/features/auth/data/dto/auth_login_response_dto.dart';
import 'package:testlabuz_client/features/auth/data/dto/auth_me_response_dto.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';

void main() {
  group('auth DTO parsing', () {
    test('parses all five locked roles', () {
      for (final role in UserRole.values) {
        expect(UserRole.parse(role.value), role);
      }
    });

    test(
      'parses institution user current session with institution context',
      () {
        final response = AuthMeResponseDto.fromJson({
          'data': _userJson(
            role: 'teacher',
            email: 'teacher@example.test',
            phone: '+998901234567',
            mustChangePassword: true,
            institution: _institutionJson(),
          ),
        });
        final user = response.user.toDomain();

        expect(user.id, 'user-1');
        expect(user.institutionId, 'institution-1');
        expect(user.role, UserRole.teacher);
        expect(user.email, 'teacher@example.test');
        expect(user.phone, '+998901234567');
        expect(user.mustChangePassword, isTrue);
        expect(user.institution?.timezone, 'Asia/Tashkent');
      },
    );

    test('parses platform owner with null institution identity', () {
      final response = AuthMeResponseDto.fromJson({
        'data': _userJson(
          role: 'platform_owner',
          institutionId: null,
          institution: null,
        ),
      });
      final user = response.user.toDomain();

      expect(user.role, UserRole.platformOwner);
      expect(user.institutionId, isNull);
      expect(user.institution, isNull);
    });

    test('preserves nullable email and phone', () {
      final response = AuthMeResponseDto.fromJson({
        'data': _userJson(institution: _institutionJson()),
      });
      final user = response.user.toDomain();

      expect(user.email, isNull);
      expect(user.phone, isNull);
    });

    test('parses must_change_password false', () {
      final response = AuthMeResponseDto.fromJson({
        'data': _userJson(
          mustChangePassword: false,
          institution: _institutionJson(),
        ),
      });

      expect(response.user.mustChangePassword, isFalse);
    });

    test(
      'parses login response token and user without institution context',
      () {
        final response = AuthLoginResponseDto.fromJson({
          'data': {
            'token': 'token-value',
            'token_type': 'Bearer',
            'user': _userJson(role: 'student'),
          },
        });

        expect(response.token, 'token-value');
        expect(response.tokenType, 'Bearer');
        expect(response.user.role, UserRole.student);
        expect(response.user.institution, isNull);
      },
    );

    test('rejects malformed role values', () {
      expect(
        () => AuthMeResponseDto.fromJson({
          'data': _userJson(role: 'custom_manager'),
        }),
        throwsFormatException,
      );
    });

    test('rejects missing required user id', () {
      final json = _userJson(institution: _institutionJson())..remove('id');

      expect(
        () => AuthMeResponseDto.fromJson({'data': json}),
        throwsFormatException,
      );
    });

    test('rejects blank required identifiers', () {
      final json = _userJson(institution: _institutionJson())..['id'] = '   ';

      expect(
        () => AuthMeResponseDto.fromJson({'data': json}),
        throwsFormatException,
      );
    });

    test('rejects non-Bearer login token type', () {
      expect(
        () => AuthLoginResponseDto.fromJson({
          'data': {
            'token': 'token-value',
            'token_type': 'Token',
            'user': _userJson(role: 'teacher'),
          },
        }),
        throwsFormatException,
      );
    });

    test('rejects missing institution id for institution users', () {
      expect(
        () => AuthMeResponseDto.fromJson({
          'data': _userJson(institutionId: null),
        }),
        throwsFormatException,
      );
    });

    test(
      'rejects missing institution context for current institution user',
      () {
        expect(
          () => AuthMeResponseDto.fromJson({
            'data': _userJson(institution: null),
          }),
          throwsFormatException,
        );
      },
    );

    test('rejects malformed institution data', () {
      final institution = _institutionJson()..remove('timezone');

      expect(
        () => AuthInstitutionDto.fromJson(institution),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _userJson({
  String role = 'teacher',
  String? institutionId = 'institution-1',
  String? email,
  String? phone,
  bool mustChangePassword = false,
  Map<String, Object?>? institution,
}) {
  return {
    'id': 'user-1',
    'institution_id': institutionId,
    'role': role,
    'full_name': 'Teacher Name',
    'login_name': 'teacher01',
    'email': email,
    'phone': phone,
    'is_active': true,
    'must_change_password': mustChangePassword,
    ...?institution == null ? null : {'institution': institution},
  };
}

Map<String, Object?> _institutionJson() {
  return {
    'id': 'institution-1',
    'name': 'Example School',
    'status': 'active',
    'timezone': 'Asia/Tashkent',
  };
}
