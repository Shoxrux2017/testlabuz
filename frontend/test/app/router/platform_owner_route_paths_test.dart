import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';

void main() {
  group('Platform Owner route paths', () {
    test('declare exact dashboard and institutions destinations', () {
      expect(AppRouteNames.platformOwner, 'platform-owner');
      expect(AppRoutePaths.platformOwner, '/platform-owner');
      expect(
        AppRouteNames.platformOwnerInstitutions,
        'platform-owner-institutions',
      );
      expect(
        AppRouteNames.platformOwnerInstitutionDetail,
        'platform-owner-institution-detail',
      );
      expect(
        AppRouteNames.platformOwnerInstitutionCreate,
        'platform-owner-institution-create',
      );
      expect(
        AppRouteNames.platformOwnerInstitutionEdit,
        'platform-owner-institution-edit',
      );
      expect(AppRoutePaths.platformOwnerInstitutionsSegment, 'institutions');
      expect(AppRoutePaths.platformOwnerInstitutionCreateSegment, 'new');
      expect(AppRoutePaths.platformOwnerInstitutionEditSegment, 'edit');
      expect(
        AppRoutePaths.platformOwnerInstitutionIdParameter,
        'institutionId',
      );
      expect(
        AppRoutePaths.platformOwnerInstitutions,
        '/platform-owner/institutions',
      );
      expect(
        AppRoutePaths.platformOwnerInstitutionCreate,
        '/platform-owner/institutions/new',
      );
      expect(
        AppRoutePaths.platformOwnerInstitutionDetail,
        '/platform-owner/institutions/:institutionId',
      );
      expect(
        AppRoutePaths.platformOwnerInstitutionEdit,
        '/platform-owner/institutions/:institutionId/edit',
      );
      expect(AppRoutePaths.platformOwnerDestinations, [
        AppRoutePaths.platformOwner,
        AppRoutePaths.platformOwnerInstitutions,
      ]);
    });

    test('match only exact approved Platform Owner destinations', () {
      expect(
        AppRoutePaths.isPlatformOwnerDestination(AppRoutePaths.platformOwner),
        isTrue,
      );
      expect(
        AppRoutePaths.isPlatformOwnerDestination(
          AppRoutePaths.platformOwnerInstitutions,
        ),
        isTrue,
      );
      expect(
        AppRoutePaths.isPlatformOwnerDestination('/platform-owner-extra'),
        isFalse,
      );
      expect(
        AppRoutePaths.isPlatformOwnerDestination('/platform-owner/settings'),
        isFalse,
      );
      expect(
        AppRoutePaths.isPlatformOwnerDestination(
          AppRoutePaths.platformOwnerInstitutionCreate,
        ),
        isFalse,
      );
      expect(
        AppRoutePaths.isPlatformOwnerDestination(
          '/platform-owner/institutions/550e8400-e29b-41d4-a716-446655440000',
        ),
        isFalse,
      );
      expect(
        AppRoutePaths.isPlatformOwnerDestination(
          '/platform-owner/institutions/550e8400-e29b-41d4-a716-446655440000/edit',
        ),
        isFalse,
      );
    });

    test('uses segment-safe Platform Owner route-family checks', () {
      expect(
        AppRoutePaths.isPlatformOwnerSegment(AppRoutePaths.platformOwner),
        isTrue,
      );
      expect(
        AppRoutePaths.isPlatformOwnerSegment(
          AppRoutePaths.platformOwnerInstitutions,
        ),
        isTrue,
      );
      expect(
        AppRoutePaths.isPlatformOwnerSegment('/platform-owner/settings'),
        isTrue,
      );
      expect(
        AppRoutePaths.isPlatformOwnerSegment('/platform-owner-extra'),
        isFalse,
      );
    });

    test(
      'recognizes and builds only one-segment institution detail and edit paths',
      () {
        const institutionId = '550e8400-e29b-41d4-a716-446655440000';

        expect(
          AppRoutePaths.platformOwnerInstitutionDetailLocation(institutionId),
          '/platform-owner/institutions/$institutionId',
        );
        expect(
          AppRoutePaths.platformOwnerInstitutionDetailLocation(
            'id with/slash?admin=true',
          ),
          '/platform-owner/institutions/id%20with%2Fslash%3Fadmin%3Dtrue',
        );
        expect(
          AppRoutePaths.platformOwnerInstitutionEditLocation(institutionId),
          '/platform-owner/institutions/$institutionId/edit',
        );
        expect(
          AppRoutePaths.platformOwnerInstitutionEditLocation(
            'id with/slash?admin=true',
          ),
          '/platform-owner/institutions/id%20with%2Fslash%3Fadmin%3Dtrue/edit',
        );
        expect(
          AppRoutePaths.isPlatformOwnerInstitutionDetailPath(
            '/platform-owner/institutions/$institutionId',
          ),
          isTrue,
        );
        expect(
          AppRoutePaths.isPlatformOwnerInstitutionDetailPath(
            '/platform-owner/institutions',
          ),
          isFalse,
        );
        expect(
          AppRoutePaths.isPlatformOwnerInstitutionDetailPath(
            '/platform-owner/institutions/',
          ),
          isFalse,
        );
        expect(
          AppRoutePaths.isPlatformOwnerInstitutionDetailPath(
            AppRoutePaths.platformOwnerInstitutionCreate,
          ),
          isFalse,
        );
        expect(
          AppRoutePaths.isPlatformOwnerInstitutionCreatePath(
            AppRoutePaths.platformOwnerInstitutionCreate,
          ),
          isTrue,
        );
        expect(
          AppRoutePaths.isPlatformOwnerInstitutionCreatePath(
            '/platform-owner/institutions/550e8400-e29b-41d4-a716-446655440000',
          ),
          isFalse,
        );
        expect(
          AppRoutePaths.isPlatformOwnerInstitutionDetailPath(
            '/platform-owner/institutions/$institutionId/edit',
          ),
          isFalse,
        );
        expect(
          AppRoutePaths.isPlatformOwnerInstitutionEditPath(
            '/platform-owner/institutions/$institutionId/edit',
          ),
          isTrue,
        );
        expect(
          AppRoutePaths.isPlatformOwnerInstitutionEditPath(
            '/platform-owner/institutions/$institutionId',
          ),
          isFalse,
        );
        expect(
          AppRoutePaths.isPlatformOwnerInstitutionEditPath(
            AppRoutePaths.platformOwnerInstitutionCreate,
          ),
          isFalse,
        );
        expect(
          AppRoutePaths.isPlatformOwnerInstitutionEditPath(
            '/platform-owner/institutions/$institutionId/edit/extra',
          ),
          isFalse,
        );
      },
    );
  });
}
