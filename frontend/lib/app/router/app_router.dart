import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/device/app_device_surface.dart';
import '../../features/auth/application/auth_session_controller.dart';
import '../../features/auth/application/auth_session_state.dart';
import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/change_password/change_password_screen.dart';
import '../../features/auth/presentation/login/login_screen.dart';
import '../../features/entry/domain/entry_route_resolver.dart';
import '../../features/entry/presentation/role_entry_screen.dart';
import 'app_route_paths.dart';
import 'technical_root_screen.dart';

export 'app_route_paths.dart';

final appInitialLocationProvider = Provider<String>((ref) {
  return AppRoutePaths.root;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(authSessionControllerProvider);
  final surface = ref.watch(appDeviceSurfaceProvider);

  return GoRouter(
    initialLocation: ref.watch(appInitialLocationProvider),
    redirect: (context, state) =>
        _authRedirect(session, surface, state.uri.path),
    routes: [
      GoRoute(
        name: AppRouteNames.technicalRoot,
        path: AppRoutePaths.root,
        builder: (context, state) => const TechnicalRootScreen(),
      ),
      GoRoute(
        name: AppRouteNames.login,
        path: AppRoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        name: AppRouteNames.changePassword,
        path: AppRoutePaths.changePassword,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        name: AppRouteNames.authenticated,
        path: AppRoutePaths.authenticated,
        builder: (context, state) => const TechnicalRootScreen(),
      ),
      GoRoute(
        name: AppRouteNames.platformOwner,
        path: AppRoutePaths.platformOwner,
        builder: (context, state) => RoleEntryScreen(
          expectedRole: UserRole.platformOwner,
          surface: surface,
        ),
      ),
      GoRoute(
        name: AppRouteNames.institutionAdmin,
        path: AppRoutePaths.institutionAdmin,
        builder: (context, state) => RoleEntryScreen(
          expectedRole: UserRole.institutionAdmin,
          surface: surface,
        ),
      ),
      GoRoute(
        name: AppRouteNames.teacher,
        path: AppRoutePaths.teacher,
        builder: (context, state) =>
            RoleEntryScreen(expectedRole: UserRole.teacher, surface: surface),
      ),
      GoRoute(
        name: AppRouteNames.student,
        path: AppRoutePaths.student,
        builder: (context, state) =>
            RoleEntryScreen(expectedRole: UserRole.student, surface: surface),
      ),
      GoRoute(
        name: AppRouteNames.parent,
        path: AppRoutePaths.parent,
        builder: (context, state) =>
            RoleEntryScreen(expectedRole: UserRole.parent, surface: surface),
      ),
      GoRoute(
        name: AppRouteNames.unsupportedDevice,
        path: AppRoutePaths.unsupportedDevice,
        builder: (context, state) => UnsupportedDeviceScreen(surface: surface),
      ),
    ],
  );
});

String? _authRedirect(
  AuthSessionState session,
  AppDeviceSurface surface,
  String location,
) {
  final isRoot = location == AppRoutePaths.root;
  final isLogin = location == AppRoutePaths.login;
  final isChangePassword = location == AppRoutePaths.changePassword;

  if (session.status == AuthSessionStatus.initial ||
      session.status == AuthSessionStatus.bootstrapping ||
      session.status == AuthSessionStatus.bootstrapFailure) {
    return isRoot ? null : AppRoutePaths.root;
  }

  if (session.status == AuthSessionStatus.unauthenticated ||
      session.status == AuthSessionStatus.authenticating) {
    return isLogin ? null : AppRoutePaths.login;
  }

  final user = session.user;
  if (user == null) {
    return isLogin ? null : AppRoutePaths.login;
  }

  if (user.mustChangePassword) {
    return isChangePassword ? null : AppRoutePaths.changePassword;
  }

  final entryPath = resolveEntryPath(user, surface);
  if (location == entryPath) {
    return null;
  }

  return entryPath;
}
