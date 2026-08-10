import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/domain/user_role.dart';

String resolveEntryPath(AuthUser user, AppDeviceSurface surface) {
  if (surface == AppDeviceSurface.unsupported) {
    return AppRoutePaths.unsupportedDevice;
  }

  return switch (surface) {
    AppDeviceSurface.desktop => _resolveDesktopEntryPath(user.role),
    AppDeviceSurface.mobile => _resolveMobileEntryPath(user.role),
    AppDeviceSurface.unsupported => AppRoutePaths.unsupportedDevice,
  };
}

String _resolveDesktopEntryPath(UserRole role) {
  return switch (role) {
    UserRole.platformOwner => AppRoutePaths.platformOwner,
    UserRole.institutionAdmin => AppRoutePaths.institutionAdmin,
    UserRole.teacher => AppRoutePaths.teacher,
    UserRole.student => AppRoutePaths.student,
    UserRole.parent => AppRoutePaths.unsupportedDevice,
  };
}

String _resolveMobileEntryPath(UserRole role) {
  return switch (role) {
    UserRole.platformOwner => AppRoutePaths.unsupportedDevice,
    UserRole.institutionAdmin => AppRoutePaths.unsupportedDevice,
    UserRole.teacher => AppRoutePaths.teacher,
    UserRole.student => AppRoutePaths.student,
    UserRole.parent => AppRoutePaths.parent,
  };
}
