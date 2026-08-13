import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/platform_admin/data/dto/platform_institution_admin_dto.dart';

void main() {
  group('PlatformInstitutionAdminDto', () {
    test(
      'decodes public admin resource and ignores protected unknown fields',
      () {
        final dto = PlatformInstitutionAdminDto.fromJson(
          _adminResource(
            extra: {
              'role': 'institution_admin',
              'institution_id': 'hidden',
              'created_by_user_id': 'owner',
              'password': 'secret',
              'password_hash': 'hash',
              'remember_token': 'token',
            },
          ),
        );
        final admin = dto.toDomain();

        expect(admin.id, '550e8400-e29b-41d4-a716-446655440001');
        expect(admin.fullName, 'Ali Valiyev');
        expect(admin.loginName, 'Admin.MixedCase');
        expect(admin.email, 'ali@example.uz');
        expect(admin.phone, '+998901234567');
        expect(admin.isActive, isTrue);
        expect(admin.mustChangePassword, isTrue);
        expect(admin.lastLoginAt, isNull);
        expect(admin.deactivatedAt, isNull);
        expect(admin.createdAt, DateTime.utc(2026, 8, 7, 15));
        expect(admin.updatedAt, DateTime.utc(2026, 8, 7, 16));
      },
    );

    test('decodes paginated admin list envelope', () {
      final dto = PlatformInstitutionAdminListDto.fromJson({
        'data': [_adminResource()],
        'meta': {
          'pagination': {
            'page': 2,
            'per_page': 50,
            'total': 51,
            'last_page': 2,
          },
        },
      });
      final page = dto.toDomain();

      expect(page.admins.single.loginName, 'Admin.MixedCase');
      expect(page.pagination.page, 2);
      expect(page.pagination.perPage, 50);
      expect(page.pagination.total, 51);
      expect(page.pagination.lastPage, 2);
    });

    test('decodes create envelope with nonempty message', () {
      final dto = PlatformInstitutionAdminCreateResponseDto.fromJson({
        'data': _adminResource(),
        'message': 'Institution admin created.',
      });
      final result = dto.toDomain();

      expect(result.admin.isActive, isTrue);
      expect(result.admin.mustChangePassword, isTrue);
      expect(result.message, 'Institution admin created.');
    });

    test('accepts inactive admins only with deactivation timestamp', () {
      final inactive = PlatformInstitutionAdminDto.fromJson(
        _adminResource(isActive: false, deactivatedAt: '2026-08-07T17:00:00Z'),
      ).toDomain();

      expect(inactive.isActive, isFalse);
      expect(inactive.deactivatedAt, DateTime.utc(2026, 8, 7, 17));
    });

    test('rejects malformed required and timestamp fields', () {
      final cases = [
        _adminResource(id: 'not-a-uuid'),
        _adminResource(fullName: ''),
        _adminResource(loginName: ''),
        _adminResource(isActive: 'true'),
        _adminResource(mustChangePassword: 1),
        _adminResource(lastLoginAt: ''),
        _adminResource(deactivatedAt: 'not-time'),
        _adminResource(isActive: true, deactivatedAt: '2026-08-07T17:00:00Z'),
        _adminResource(isActive: false, deactivatedAt: null),
        _adminResource(createdAt: '2026-08-07 15:00:00'),
        _adminResource(updatedAt: 'not-time'),
      ];

      for (final json in cases) {
        expect(
          () => PlatformInstitutionAdminDto.fromJson(json),
          throwsFormatException,
        );
      }
    });
  });
}

Map<String, Object?> _adminResource({
  String id = '550e8400-e29b-41d4-a716-446655440001',
  String fullName = 'Ali Valiyev',
  String loginName = 'Admin.MixedCase',
  Object? email = 'ali@example.uz',
  Object? phone = '+998901234567',
  Object? isActive = true,
  Object? mustChangePassword = true,
  Object? lastLoginAt,
  Object? deactivatedAt,
  String createdAt = '2026-08-07T15:00:00Z',
  String updatedAt = '2026-08-07T16:00:00Z',
  Map<String, Object?> extra = const {},
}) {
  return {
    'id': id,
    'full_name': fullName,
    'login_name': loginName,
    'email': email,
    'phone': phone,
    'is_active': isActive,
    'must_change_password': mustChangePassword,
    'last_login_at': lastLoginAt,
    'deactivated_at': deactivatedAt,
    'created_at': createdAt,
    'updated_at': updatedAt,
    ...extra,
  };
}
