import 'package:flutter/widgets.dart';
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
import '../../features/institution_admin/presentation/institution_admin_dashboard_screen.dart';
import '../../features/institution_admin/presentation/institution_admin_group_create_screen.dart';
import '../../features/institution_admin/presentation/institution_admin_group_detail_screen.dart';
import '../../features/institution_admin/presentation/institution_admin_groups_screen.dart';
import '../../features/institution_admin/presentation/institution_admin_parent_student_connections_screen.dart';
import '../../features/institution_admin/presentation/institution_admin_profile_screen.dart';
import '../../features/institution_admin/presentation/institution_admin_placeholder_screen.dart';
import '../../features/institution_admin/presentation/institution_admin_settings_screen.dart';
import '../../features/institution_admin/presentation/institution_admin_shell.dart';
import '../../features/platform_admin/presentation/platform_owner_dashboard_screen.dart';
import '../../features/platform_admin/presentation/platform_owner_institution_create_screen.dart';
import '../../features/platform_admin/presentation/platform_owner_institution_detail_screen.dart';
import '../../features/platform_admin/presentation/platform_owner_institution_edit_screen.dart';
import '../../features/platform_admin/presentation/platform_owner_institutions_screen.dart';
import '../../features/platform_admin/presentation/platform_owner_shell.dart';
import '../../features/student/application/student_session_key.dart';
import '../../features/student/presentation/student_learning_workspace_screen.dart';
import '../../features/student/presentation/student_topic_detail_screen.dart';
import '../../features/teacher/presentation/teacher_learning_workspace_screen.dart';
import '../../features/teacher/presentation/teacher_topic_create_screen.dart';
import '../../features/teacher/presentation/teacher_topic_detail_screen.dart';
import '../../features/teacher/presentation/teacher_topic_edit_screen.dart';
import '../../features/teacher/application/teacher_session_key.dart';
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
    initialLocation: _safeInitialLocation(
      ref.watch(appInitialLocationProvider),
    ),
    refreshListenable: refresh,
    redirect: (context, state) => _authRedirect(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
      state.uri.path,
      hasQueryOrFragment: state.uri.hasQuery || state.uri.hasFragment,
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
            name: AppRouteNames.platformOwnerInstitutionCreate,
            path: AppRoutePaths.platformOwnerInstitutionCreate,
            builder: (context, state) =>
                const PlatformOwnerInstitutionCreateScreen(),
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
          GoRoute(
            name: AppRouteNames.platformOwnerInstitutionEdit,
            path: AppRoutePaths.platformOwnerInstitutionEdit,
            builder: (context, state) => PlatformOwnerInstitutionEditScreen(
              institutionId:
                  state.pathParameters[AppRoutePaths
                      .platformOwnerInstitutionIdParameter] ??
                  '',
            ),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            name: AppRouteNames.institutionAdmin,
            path: AppRoutePaths.institutionAdmin,
            builder: (context, state) => _buildInstitutionAdminShell(
              state,
              const InstitutionAdminDashboardScreen(),
            ),
          ),
          GoRoute(
            name: AppRouteNames.institutionAdminUsers,
            path: AppRoutePaths.institutionAdminUsers,
            builder: (context, state) => _buildInstitutionAdminShell(
              state,
              const InstitutionAdminUsersPlaceholderScreen(),
            ),
          ),
          GoRoute(
            name: AppRouteNames.institutionAdminGroups,
            path: AppRoutePaths.institutionAdminGroups,
            builder: (context, state) => _buildInstitutionAdminShell(
              state,
              const InstitutionAdminGroupsScreen(),
            ),
          ),
          GoRoute(
            name: AppRouteNames.institutionAdminGroupCreate,
            path: AppRoutePaths.institutionAdminGroupCreate,
            builder: (context, state) => _buildInstitutionAdminShell(
              state,
              const InstitutionAdminGroupCreateScreen(),
            ),
          ),
          GoRoute(
            name: AppRouteNames.institutionAdminGroupDetail,
            path: AppRoutePaths.institutionAdminGroupDetail,
            builder: (context, state) {
              if (state.uri.hasQuery ||
                  state.uri.hasFragment ||
                  !AppRoutePaths.isInstitutionAdminGroupDetailPath(
                    state.uri.path,
                  )) {
                return const TechnicalRootScreen();
              }

              return _buildInstitutionAdminShell(
                state,
                InstitutionAdminGroupDetailScreen(
                  groupId:
                      state.pathParameters[AppRoutePaths
                          .institutionAdminGroupIdParameter] ??
                      '',
                ),
              );
            },
          ),
          GoRoute(
            name: AppRouteNames.institutionAdminUserCreate,
            path: AppRoutePaths.institutionAdminUserCreate,
            builder: (context, state) => _buildInstitutionAdminShell(
              state,
              const InstitutionAdminUserCreatePlaceholderScreen(),
            ),
          ),
          GoRoute(
            name: AppRouteNames.institutionAdminParentStudentConnections,
            path: AppRoutePaths.institutionAdminParentStudentConnections,
            builder: (context, state) => _buildInstitutionAdminShell(
              state,
              const InstitutionAdminParentStudentConnectionsScreen(),
            ),
          ),
          GoRoute(
            name: AppRouteNames.institutionAdminUserDetail,
            path: AppRoutePaths.institutionAdminUserDetail,
            builder: (context, state) {
              if (state.uri.hasQuery ||
                  state.uri.hasFragment ||
                  !AppRoutePaths.isInstitutionAdminUserDetailPath(
                    state.uri.path,
                  )) {
                return const TechnicalRootScreen();
              }

              return _buildInstitutionAdminShell(
                state,
                InstitutionAdminUserDetailPlaceholderScreen(
                  userId:
                      state.pathParameters[AppRoutePaths
                          .institutionAdminUserIdParameter] ??
                      '',
                ),
              );
            },
          ),
          GoRoute(
            name: AppRouteNames.institutionAdminInstitution,
            path: AppRoutePaths.institutionAdminInstitution,
            builder: (context, state) => _buildInstitutionAdminShell(
              state,
              const InstitutionAdminProfileScreen(),
            ),
          ),
          GoRoute(
            name: AppRouteNames.institutionAdminSettings,
            path: AppRoutePaths.institutionAdminSettings,
            builder: (context, state) => _buildInstitutionAdminShell(
              state,
              InstitutionAdminSettingsScreen(routePath: state.uri.path),
            ),
          ),
        ],
      ),
      GoRoute(
        name: AppRouteNames.teacher,
        path: AppRoutePaths.teacher,
        builder: (context, state) =>
            _buildTeacherDestination(const TeacherLearningWorkspaceScreen()),
        routes: [
          GoRoute(
            name: AppRouteNames.teacherTopicCreate,
            path:
                '${AppRoutePaths.teacherTopicsSegment}/${AppRoutePaths.teacherTopicCreateSegment}',
            builder: (context, state) => _buildTeacherDestination(
              const TeacherTopicCreateScreen(),
              authoring: true,
            ),
          ),
          GoRoute(
            name: AppRouteNames.teacherTopicDetail,
            path:
                '${AppRoutePaths.teacherTopicsSegment}/:${AppRoutePaths.teacherTopicIdParameter}',
            builder: (context, state) => _buildTeacherDestination(
              TeacherTopicDetailScreen(
                topicId:
                    state.pathParameters[AppRoutePaths
                        .teacherTopicIdParameter] ??
                    '',
              ),
            ),
            routes: [
              GoRoute(
                name: AppRouteNames.teacherTopicEdit,
                path: AppRoutePaths.teacherTopicEditSegment,
                builder: (context, state) => _buildTeacherDestination(
                  TeacherTopicEditScreen(
                    topicId:
                        state.pathParameters[AppRoutePaths
                            .teacherTopicIdParameter] ??
                        '',
                  ),
                  authoring: true,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        name: AppRouteNames.student,
        path: AppRoutePaths.student,
        builder: (context, state) =>
            _buildStudentDestination(const StudentLearningWorkspaceScreen()),
        routes: [
          GoRoute(
            name: AppRouteNames.studentTopicDetail,
            path:
                '${AppRoutePaths.studentTopicsSegment}/:${AppRoutePaths.studentTopicIdParameter}',
            builder: (context, state) => _buildStudentDestination(
              StudentTopicDetailScreen(
                topicId:
                    state.pathParameters[AppRoutePaths
                        .studentTopicIdParameter] ??
                    '',
              ),
            ),
          ),
        ],
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

Widget _buildInstitutionAdminShell(GoRouterState state, Widget child) {
  return InstitutionAdminShell(locationPath: state.uri.path, child: child);
}

Widget _buildTeacherDestination(Widget child, {bool authoring = false}) {
  return _TeacherDestinationGate(authoring: authoring, child: child);
}

Widget _buildStudentDestination(Widget child) {
  return _StudentDestinationGate(child: child);
}

class _TeacherDestinationGate extends ConsumerWidget {
  const _TeacherDestinationGate({required this.authoring, required this.child});

  final bool authoring;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null ||
        (authoring && sessionKey.surface != AppDeviceSurface.desktop)) {
      return const TechnicalRootScreen();
    }

    return child;
  }
}

class _StudentDestinationGate extends ConsumerWidget {
  const _StudentDestinationGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionKey = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null) {
      return const TechnicalRootScreen();
    }

    return child;
  }
}

String _safeInitialLocation(String requestedLocation) {
  final uri = Uri.tryParse(requestedLocation);
  if (uri == null) {
    return requestedLocation;
  }

  final path = uri.path;
  if (path.length > 1 && path.endsWith('/')) {
    final withoutFinalSlash = path.substring(0, path.length - 1);
    if (AppRoutePaths.isInstitutionAdminSegment(withoutFinalSlash)) {
      return AppRoutePaths.institutionAdmin;
    }
  }

  return requestedLocation;
}

String? _authRedirect(
  AuthSessionState session,
  AppDeviceSurface surface,
  String location, {
  required bool hasQueryOrFragment,
}) {
  final isRoot = location == AppRoutePaths.root;
  final isLogin = location == AppRoutePaths.login;
  final isChangePassword = location == AppRoutePaths.changePassword;

  if (session.status == AuthSessionStatus.initial ||
      session.status == AuthSessionStatus.bootstrapping) {
    if (!hasQueryOrFragment &&
        surface == AppDeviceSurface.mobile &&
        AppRoutePaths.isTeacherSegment(location)) {
      if (AppRoutePaths.isTeacherTopicEditPath(location)) {
        final topicId = AppRoutePaths.teacherTopicIdFromPath(location)!;
        return AppRoutePaths.teacherTopicDetailLocation(topicId);
      }
      if (AppRoutePaths.isTeacherTopicCreatePath(location)) {
        return AppRoutePaths.teacher;
      }
    }
    if (_keepsLocationDuringBootstrap(
      location,
      surface,
      hasQueryOrFragment: hasQueryOrFragment,
    )) {
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

  if (_canUseInstitutionAdminDestinations(user.role, surface)) {
    if ((AppRoutePaths.isInstitutionAdminUserDetailPath(location) ||
            AppRoutePaths.isInstitutionAdminGroupDetailPath(location)) &&
        hasQueryOrFragment) {
      return AppRoutePaths.institutionAdmin;
    }

    if (AppRoutePaths.isInstitutionAdminApprovedLocation(location)) {
      return null;
    }

    if (AppRoutePaths.isInstitutionAdminSegment(location)) {
      return AppRoutePaths.institutionAdmin;
    }
  }

  if (_canUseTeacherDestinations(user.role, surface) &&
      AppRoutePaths.isTeacherSegment(location)) {
    if (hasQueryOrFragment) {
      return AppRoutePaths.teacher;
    }
    if (surface == AppDeviceSurface.desktop &&
        AppRoutePaths.isTeacherApprovedLocation(location)) {
      return null;
    }
    if (surface == AppDeviceSurface.mobile) {
      if (AppRoutePaths.isTeacherTopicDetailPath(location)) {
        return null;
      }
      if (AppRoutePaths.isTeacherTopicEditPath(location)) {
        final topicId = AppRoutePaths.teacherTopicIdFromPath(location);
        return topicId == null
            ? AppRoutePaths.teacher
            : AppRoutePaths.teacherTopicDetailLocation(topicId);
      }
      if (location == AppRoutePaths.teacher) {
        return null;
      }
    }

    return AppRoutePaths.teacher;
  }

  if (_canUseStudentDestinations(user.role, surface) &&
      AppRoutePaths.isStudentSegment(location)) {
    if (hasQueryOrFragment) {
      return AppRoutePaths.student;
    }
    if (AppRoutePaths.isStudentApprovedLocation(location)) {
      return null;
    }

    return AppRoutePaths.student;
  }

  if (location == entryPath) {
    return null;
  }

  return entryPath;
}

bool _canUsePlatformOwnerDestinations(UserRole role, AppDeviceSurface surface) {
  return role == UserRole.platformOwner && surface == AppDeviceSurface.desktop;
}

bool _canUseInstitutionAdminDestinations(
  UserRole role,
  AppDeviceSurface surface,
) {
  return role == UserRole.institutionAdmin &&
      surface == AppDeviceSurface.desktop;
}

bool _keepsLocationDuringBootstrap(
  String location,
  AppDeviceSurface surface, {
  required bool hasQueryOrFragment,
}) {
  if (hasQueryOrFragment) {
    return false;
  }

  return (AppRoutePaths.protected.contains(location) &&
          !AppRoutePaths.isInstitutionAdminSegment(location)) ||
      AppRoutePaths.isPlatformOwnerSegment(location) ||
      AppRoutePaths.isInstitutionAdminApprovedLocation(location) ||
      (AppRoutePaths.isTeacherTopicDetailPath(location) &&
          (surface == AppDeviceSurface.desktop ||
              surface == AppDeviceSurface.mobile)) ||
      (AppRoutePaths.isStudentTopicDetailPath(location) &&
          (surface == AppDeviceSurface.desktop ||
              surface == AppDeviceSurface.mobile)) ||
      (surface == AppDeviceSurface.desktop &&
          (AppRoutePaths.isTeacherTopicCreatePath(location) ||
              AppRoutePaths.isTeacherTopicEditPath(location)));
}

bool _canUseTeacherDestinations(UserRole role, AppDeviceSurface surface) {
  return role == UserRole.teacher &&
      (surface == AppDeviceSurface.desktop ||
          surface == AppDeviceSurface.mobile);
}

bool _canUseStudentDestinations(UserRole role, AppDeviceSurface surface) {
  return role == UserRole.student &&
      (surface == AppDeviceSurface.desktop ||
          surface == AppDeviceSurface.mobile);
}

class _AppRouterRefresh extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}
