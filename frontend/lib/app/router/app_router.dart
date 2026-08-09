import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_session_controller.dart';
import '../../features/auth/application/auth_session_state.dart';
import '../../features/auth/presentation/change_password/change_password_screen.dart';
import '../../features/auth/presentation/login/login_screen.dart';
import 'authenticated_transition_screen.dart';
import 'technical_root_screen.dart';

final appInitialLocationProvider = Provider<String>((ref) {
  return AppRoutePaths.root;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(authSessionControllerProvider);

  return GoRouter(
    initialLocation: ref.watch(appInitialLocationProvider),
    redirect: (context, state) => _authRedirect(session, state.uri.path),
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
        builder: (context, state) => const AuthenticatedTransitionScreen(),
      ),
    ],
  );
});

String? _authRedirect(AuthSessionState session, String location) {
  final isRoot = location == AppRoutePaths.root;
  final isLogin = location == AppRoutePaths.login;
  final isChangePassword = location == AppRoutePaths.changePassword;
  final isAuthenticated = location == AppRoutePaths.authenticated;

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

  return isAuthenticated ? null : AppRoutePaths.authenticated;
}

abstract final class AppRouteNames {
  static const technicalRoot = 'technical-root';
  static const login = 'login';
  static const changePassword = 'change-password';
  static const authenticated = 'authenticated';
}

abstract final class AppRoutePaths {
  static const root = '/';
  static const login = '/login';
  static const changePassword = '/change-password';
  static const authenticated = '/authenticated';

  static const all = <String>[root, login, changePassword, authenticated];
}
