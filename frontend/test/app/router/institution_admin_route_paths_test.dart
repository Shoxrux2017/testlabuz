import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';

void main() {
  group('Institution Admin route declarations', () {
    test('declare exact names paths segments parameter and primary order', () {
      expect(AppRouteNames.institutionAdmin, 'institution-admin');
      expect(AppRouteNames.institutionAdminUsers, 'institution-admin-users');
      expect(
        AppRouteNames.institutionAdminUserCreate,
        'institution-admin-user-create',
      );
      expect(
        AppRouteNames.institutionAdminUserDetail,
        'institution-admin-user-detail',
      );
      expect(
        AppRouteNames.institutionAdminInstitution,
        'institution-admin-institution',
      );
      expect(
        AppRouteNames.institutionAdminSettings,
        'institution-admin-settings',
      );

      expect(AppRoutePaths.institutionAdmin, '/institution-admin');
      expect(AppRoutePaths.institutionAdminUsersSegment, 'users');
      expect(AppRoutePaths.institutionAdminUserCreateSegment, 'new');
      expect(AppRoutePaths.institutionAdminUserIdParameter, 'userId');
      expect(AppRoutePaths.institutionAdminInstitutionSegment, 'institution');
      expect(AppRoutePaths.institutionAdminSettingsSegment, 'settings');
      expect(AppRoutePaths.institutionAdminUsers, '/institution-admin/users');
      expect(
        AppRoutePaths.institutionAdminUserCreate,
        '/institution-admin/users/new',
      );
      expect(
        AppRoutePaths.institutionAdminUserDetail,
        '/institution-admin/users/:userId',
      );
      expect(
        AppRoutePaths.institutionAdminInstitution,
        '/institution-admin/institution',
      );
      expect(
        AppRoutePaths.institutionAdminSettings,
        '/institution-admin/settings',
      );
      expect(AppRoutePaths.institutionAdminPrimaryDestinations, const [
        AppRoutePaths.institutionAdmin,
        AppRoutePaths.institutionAdminUsers,
        AppRoutePaths.institutionAdminInstitution,
        AppRoutePaths.institutionAdminSettings,
      ]);
    });

    test('declare every route pattern once with globally unique names', () {
      const institutionAdminNames = <String>[
        AppRouteNames.institutionAdmin,
        AppRouteNames.institutionAdminUsers,
        AppRouteNames.institutionAdminUserCreate,
        AppRouteNames.institutionAdminUserDetail,
        AppRouteNames.institutionAdminInstitution,
        AppRouteNames.institutionAdminSettings,
      ];
      const allNames = <String>[
        AppRouteNames.technicalRoot,
        AppRouteNames.login,
        AppRouteNames.changePassword,
        AppRouteNames.authenticated,
        AppRouteNames.platformOwner,
        AppRouteNames.platformOwnerInstitutions,
        AppRouteNames.platformOwnerInstitutionCreate,
        AppRouteNames.platformOwnerInstitutionDetail,
        AppRouteNames.platformOwnerInstitutionEdit,
        ...institutionAdminNames,
        AppRouteNames.teacher,
        AppRouteNames.student,
        AppRouteNames.parent,
        AppRouteNames.unsupportedDevice,
      ];
      const patterns = <String>[
        AppRoutePaths.institutionAdmin,
        AppRoutePaths.institutionAdminUsers,
        AppRoutePaths.institutionAdminUserCreate,
        AppRoutePaths.institutionAdminUserDetail,
        AppRoutePaths.institutionAdminInstitution,
        AppRoutePaths.institutionAdminSettings,
      ];

      expect(allNames.toSet(), hasLength(allNames.length));
      expect(institutionAdminNames.toSet(), hasLength(6));
      expect(patterns.toSet(), hasLength(6));
      for (final pattern in patterns) {
        expect(
          AppRoutePaths.protected.where((path) => path == pattern),
          hasLength(1),
        );
        expect(
          AppRoutePaths.all.where((path) => path == pattern),
          hasLength(1),
        );
      }
    });
  });

  group('Institution Admin exact location classification', () {
    test(
      'recognizes only exact primary static create and detail locations',
      () {
        for (final path in AppRoutePaths.institutionAdminPrimaryDestinations) {
          expect(
            AppRoutePaths.isInstitutionAdminPrimaryDestination(path),
            isTrue,
          );
          expect(
            AppRoutePaths.isInstitutionAdminApprovedLocation(path),
            isTrue,
          );
        }

        expect(
          AppRoutePaths.isInstitutionAdminUserCreatePath(
            AppRoutePaths.institutionAdminUserCreate,
          ),
          isTrue,
        );
        expect(
          AppRoutePaths.isInstitutionAdminApprovedLocation(
            AppRoutePaths.institutionAdminUserCreate,
          ),
          isTrue,
        );
        for (final userId in const [_lowerUuid, _upperUuid]) {
          final path = AppRoutePaths.institutionAdminUserDetailLocation(userId);
          expect(AppRoutePaths.isInstitutionAdminUserDetailPath(path), isTrue);
          expect(
            AppRoutePaths.isInstitutionAdminApprovedLocation(path),
            isTrue,
          );
          expect(
            AppRoutePaths.isInstitutionAdminPrimaryDestination(path),
            isFalse,
          );
        }
      },
    );

    test('rejects malformed descendants trailing paths and prefix lookalikes', () {
      const malformedPaths = <String>[
        '/institution-admin-extra',
        '/institution-admin/',
        '/institution-admin/users/',
        '/institution-admin/users/new/extra',
        '/institution-admin/users//',
        '/institution-admin/users/not-a-uuid',
        '/institution-admin/users/550e8400-e29b-41d4-a716-446655440000/extra',
        '/institution-admin/institution/edit',
        '/institution-admin/settings/categories',
        '/institution-admin/users/:userId',
        '/institution-admin/users/550e8400-e29b-41d4-a716-446655440000?admin=true',
        '/institution-admin/users/550e8400-e29b-41d4-a716-446655440000#details',
        '/institution-admin/users/550e8400-e29b-41d4-a716-446655440000/',
      ];

      for (final path in malformedPaths) {
        expect(
          AppRoutePaths.isInstitutionAdminApprovedLocation(path),
          isFalse,
          reason: path,
        );
      }
      expect(
        AppRoutePaths.isInstitutionAdminSegment('/institution-admin-extra'),
        isFalse,
      );
      expect(
        AppRoutePaths.isInstitutionAdminSegment(
          '/institution-admin/settings/categories',
        ),
        isTrue,
      );
    });
  });

  group('Institution Admin User detail UUID boundary', () {
    test('builds lower and upper canonical UUID locations safely', () {
      expect(
        AppRoutePaths.institutionAdminUserDetailLocation(_lowerUuid),
        '/institution-admin/users/$_lowerUuid',
      );
      expect(
        AppRoutePaths.institutionAdminUserDetailLocation(_upperUuid),
        '/institution-admin/users/$_upperUuid',
      );
    });

    test('does not interpret static new as a User detail identifier', () {
      expect(
        AppRoutePaths.isInstitutionAdminUserCreatePath(
          AppRoutePaths.institutionAdminUserCreate,
        ),
        isTrue,
      );
      expect(
        AppRoutePaths.isInstitutionAdminUserDetailPath(
          AppRoutePaths.institutionAdminUserCreate,
        ),
        isFalse,
      );
      expect(
        () => AppRoutePaths.institutionAdminUserDetailLocation('new'),
        throwsArgumentError,
      );
    });

    test('rejects every malformed or path-manipulation User ID input', () {
      const malformedUserIds = <String>[
        '',
        ' ',
        ' $_lowerUuid',
        '$_lowerUuid ',
        'new',
        'not-a-uuid',
        '550e8400-e29b-41d4-a716-44665544000',
        '550e8400-e29b-41d4-a716-4466554400000',
        '{550e8400-e29b-41d4-a716-446655440000}',
        '550e8400e29b41d4a716446655440000',
        '550e8400-e29b-41d4-a716-446655440000/extra',
        r'550e8400-e29b-41d4-a716-446655440000\extra',
        '../550e8400-e29b-41d4-a716-446655440000',
        '550e8400-e29b-41d4-a716-446655440000?admin=true',
        '550e8400-e29b-41d4-a716-446655440000#fragment',
        '550e8400-e29b-41d4-a716-446655440000\n',
        '550e8400-e29b-41d4-a716-446655440000%2Fextra',
        '550e8400-e29b-41d4-a716-446655440000%5Cextra',
      ];

      for (final userId in malformedUserIds) {
        expect(
          () => AppRoutePaths.institutionAdminUserDetailLocation(userId),
          throwsArgumentError,
          reason: userId,
        );
      }
    });
  });
}

const _lowerUuid = '550e8400-e29b-41d4-a716-446655440000';
const _upperUuid = 'A0B1C2D3-E4F5-6789-ABCD-EF0123456789';
