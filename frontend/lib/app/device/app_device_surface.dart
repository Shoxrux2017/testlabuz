import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppDeviceSurface {
  desktop('desktop'),
  mobile('mobile'),
  unsupported('unsupported');

  const AppDeviceSurface(this.label);

  final String label;
}

final appDeviceSurfaceProvider = Provider<AppDeviceSurface>((ref) {
  return resolveAppDeviceSurface(
    platform: defaultTargetPlatform,
    isWeb: kIsWeb,
  );
});

AppDeviceSurface resolveAppDeviceSurface({
  required TargetPlatform platform,
  required bool isWeb,
}) {
  if (isWeb) {
    return AppDeviceSurface.unsupported;
  }

  return switch (platform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => AppDeviceSurface.desktop,
    TargetPlatform.android || TargetPlatform.iOS => AppDeviceSurface.mobile,
    TargetPlatform.fuchsia => AppDeviceSurface.unsupported,
  };
}
