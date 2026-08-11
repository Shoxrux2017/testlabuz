import 'package:flutter/foundation.dart';
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
import '../../features/platform_admin/presentation/platform_owner_dashboard_screen.dart';
import '../../features/platform_admin/presentation/platform_owner_institution_detail_screen.dart';
import '../../features/platform_admin/presentation/platform_owner_institutions_screen.dart';
import '../../features/platform_admin/presentation/platform_owner_shell.dart';
import 'app_route_paths.dart';
import 'technical_root_screen.dart';

export 'app_route_paths.dart';

final appInitialLocationProvider = Provider<String>((ref) {
  return AppRoutePaths.root;
});

final _appRouterRefreshProvider = Provider<_AppRouterRefresh>((ref) {
  final refresh = _AppRouterRefresh();

  ref
    ..listen(authSessionControllerProvider, (_, _) => refresh.notify())
    ..listen(appDeviceSurfaceProvider, (_, _) => refresh.notify())
    ..onDispose(refresh.dispose);

  return refresh;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_appRouterRefreshProvider);
  final previousUrlReflection = GoRouter.optionURLReflectsImperativeAPIs;

  GoRouter.optionURLReflectsImperativeAPIs = true;
  ref.onDispose(() {
    GoRouter.optionURLReflectsImperativeAPIs = previousUrlReflection;
  });

  return GoRouter(
    initialLocation: ref.watch(appInitialLocationProvider),
    refreshListenable: refresh,
    redirect: (context, state) => _authRedirect(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
      state.uri.path,
    ),
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
      ShellRoute(
        builder: (context, state, child) =>
            PlatformOwnerShell(locationPath: state.uri.path, child: child),
        routes: [
          GoRoute(
            name: AppRouteNames.platformOwner,
            path: AppRoutePaths.platformOwner,
            builder: (context, state) => const PlatformOwnerDashboardScreen(),
          ),
          GoRoute(
            name: AppRouteNames.platformOwnerInstitutions,
            path: AppRoutePaths.platformOwnerInstitutions,
            builder: (context, state) =>
                const PlatformOwnerInstitutionsScreen(),
          ),
          GoRoute(
            name: AppRouteNames.platformOwnerInstitutionDetail,
            path: AppRoutePaths.platformOwnerInstitutionDetail,
            builder: (context, state) => PlatformOwnerInstitutionDetailScreen(
              institutionId:
                  state.pathParameters[AppRoutePaths
                      .platformOwnerInstitutionIdParameter] ??
                  '',
            ),
          ),
        ],
      ),
      GoRoute(
        name: AppRouteNames.institutionAdmin,
        path: AppRoutePaths.institutionAdmin,
        builder: (context, state) => RoleEntryScreen(
          expectedRole: UserRole.institutionAdmin,
          surface: ref.read(appDeviceSurfaceProvider),
        ),
      ),
      GoRoute(
        name: AppRouteNames.teacher,
        path: AppRoutePaths.teacher,
        builder: (context, state) => RoleEntryScreen(
          expectedRole: UserRole.teacher,
          surface: ref.read(appDeviceSurfaceProvider),
        ),
      ),
      GoRoute(
        name: AppRouteNames.student,
        path: AppRoutePaths.student,
        builder: (context, state) => RoleEntryScreen(
          expectedRole: UserRole.student,
          surface: ref.read(appDeviceSurfaceProvider),
        ),
      ),
      GoRoute(
        name: AppRouteNames.parent,
        path: AppRoutePaths.parent,
        builder: (context, state) => RoleEntryScreen(
          expectedRole: UserRole.parent,
          surface: ref.read(appDeviceSurfaceProvider),
        ),
      ),
      GoRoute(
        name: AppRouteNames.unsupportedDevice,
        path: AppRoutePaths.unsupportedDevice,
        builder: (context, state) => UnsupportedDeviceScreen(
          surface: ref.read(appDeviceSurfaceProvider),
        ),
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
      session.status == AuthSessionStatus.bootstrapping) {
    if (_keepsLocationDuringBootstrap(location)) {
      return null;
    }

    return isRoot ? null : AppRoutePaths.root;
  }

  if (session.status == AuthSessionStatus.bootstrapFailure) {
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
  if (_canUsePlatformOwnerDestinations(user.role, surface)) {
    if (AppRoutePaths.isPlatformOwnerDestination(location)) {
      return null;
    }

    if (AppRoutePaths.isPlatformOwnerSegment(location)) {
      return null;
    }
  }

  if (location == entryPath) {
    return null;
  }

  return entryPath;
}

bool _canUsePlatformOwnerDestinations(UserRole role, AppDeviceSurface surface) {
  return role == UserRole.platformOwner && surface == AppDeviceSurface.desktop;
}

bool _keepsLocationDuringBootstrap(String location) {
  return AppRoutePaths.protected.contains(location) ||
      AppRoutePaths.isPlatformOwnerSegment(location);
}

class _AppRouterRefresh extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}
