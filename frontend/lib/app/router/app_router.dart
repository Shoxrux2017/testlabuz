import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'technical_root_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutePaths.root,
    routes: [
      GoRoute(
        name: AppRouteNames.technicalRoot,
        path: AppRoutePaths.root,
        builder: (context, state) => const TechnicalRootScreen(),
      ),
    ],
  );
});

abstract final class AppRouteNames {
  static const technicalRoot = 'technical-root';
}

abstract final class AppRoutePaths {
  static const root = '/';

  static const all = <String>[root];
}
