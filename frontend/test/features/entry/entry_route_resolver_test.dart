import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/entry/domain/entry_route_resolver.dart';

void main() {
  group('resolveEntryPath', () {
    test('resolves the approved desktop role matrix', () {
      expect(
        resolveEntryPath(
          _user(role: UserRole.platformOwner),
          AppDeviceSurface.desktop,
        ),
        AppRoutePaths.platformOwner,
      );
      expect(
        resolveEntryPath(
          _user(role: UserRole.institutionAdmin),
          AppDeviceSurface.desktop,
        ),
        AppRoutePaths.institutionAdmin,
      );
      expect(
        resolveEntryPath(
          _user(role: UserRole.teacher),
          AppDeviceSurface.desktop,
        ),
        AppRoutePaths.teacher,
      );
      expect(
        resolveEntryPath(
          _user(role: UserRole.student),
          AppDeviceSurface.desktop,
        ),
        AppRoutePaths.student,
      );
      expect(
        resolveEntryPath(
          _user(role: UserRole.parent),
          AppDeviceSurface.desktop,
        ),
        AppRoutePaths.unsupportedDevice,
      );
    });

    test('resolves the approved mobile role matrix', () {
      expect(
        resolveEntryPath(
          _user(role: UserRole.platformOwner),
          AppDeviceSurface.mobile,
        ),
        AppRoutePaths.unsupportedDevice,
      );
      expect(
        resolveEntryPath(
          _user(role: UserRole.institutionAdmin),
          AppDeviceSurface.mobile,
        ),
        AppRoutePaths.unsupportedDevice,
      );
      expect(
        resolveEntryPath(
          _user(role: UserRole.teacher),
          AppDeviceSurface.mobile,
        ),
        AppRoutePaths.teacher,
      );
      expect(
        resolveEntryPath(
          _user(role: UserRole.student),
          AppDeviceSurface.mobile,
        ),
        AppRoutePaths.student,
      );
      expect(
        resolveEntryPath(_user(role: UserRole.parent), AppDeviceSurface.mobile),
        AppRoutePaths.parent,
      );
    });

    test('resolves every role to unsupported on unsupported platforms', () {
      for (final role in UserRole.values) {
        expect(
          resolveEntryPath(_user(role: role), AppDeviceSurface.unsupported),
          AppRoutePaths.unsupportedDevice,
        );
      }
    });
  });
}

AuthUser _user({required UserRole role}) {
  return AuthUser(
    id: '${role.value}-id',
    institutionId: role == UserRole.platformOwner ? null : 'institution-1',
    role: role,
    fullName: 'Test User',
    loginName: role.value,
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: false,
    institution: role == UserRole.platformOwner
        ? null
        : const AuthInstitution(
            id: 'institution-1',
            name: 'Example School',
            status: 'active',
            timezone: 'Asia/Tashkent',
          ),
  );
}
