import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';

void main() {
  group('resolveAppDeviceSurface', () {
    test('maps desktop platforms to desktop', () {
      expect(
        resolveAppDeviceSurface(platform: TargetPlatform.windows, isWeb: false),
        AppDeviceSurface.desktop,
      );
      expect(
        resolveAppDeviceSurface(platform: TargetPlatform.macOS, isWeb: false),
        AppDeviceSurface.desktop,
      );
      expect(
        resolveAppDeviceSurface(platform: TargetPlatform.linux, isWeb: false),
        AppDeviceSurface.desktop,
      );
    });

    test('maps mobile platforms to mobile', () {
      expect(
        resolveAppDeviceSurface(platform: TargetPlatform.android, isWeb: false),
        AppDeviceSurface.mobile,
      );
      expect(
        resolveAppDeviceSurface(platform: TargetPlatform.iOS, isWeb: false),
        AppDeviceSurface.mobile,
      );
    });

    test('maps web to unsupported regardless of platform', () {
      for (final platform in TargetPlatform.values) {
        expect(
          resolveAppDeviceSurface(platform: platform, isWeb: true),
          AppDeviceSurface.unsupported,
        );
      }
    });
  });
}
