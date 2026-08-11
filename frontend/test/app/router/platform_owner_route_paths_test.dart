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
      expect(AppRoutePaths.platformOwnerInstitutionsSegment, 'institutions');
      expect(
        AppRoutePaths.platformOwnerInstitutions,
        '/platform-owner/institutions',
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
  });
}
