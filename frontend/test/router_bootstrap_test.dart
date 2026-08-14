import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/session_invalidation_signal.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_list_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard_repository.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_query.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_list_repository.dart';

void main() {
  group('router auth guard precedence', () {
    testWidgets('unauthenticated protected routes resolve to login', (
      tester,
    ) async {
      for (final protectedPath in AppRoutePaths.protected) {
        await _pumpApp(
          tester,
          initialLocation: protectedPath,
          repository: FakeAuthRepository(),
        );
        await tester.pumpAndSettle();

        expect(find.text('Login'), findsOneWidget);
        expect(find.text('Platform Owner'), findsNothing);
        expect(find.text('Institution Admin'), findsNothing);
        expect(find.text('Teacher'), findsNothing);
        expect(find.text('Student'), findsNothing);
        expect(find.text('Parent'), findsNothing);
      }
    });

    testWidgets('must-change users are forced to change password first', (
      tester,
    ) async {
      for (final role in UserRole.values) {
        for (final protectedPath in AppRoutePaths.protected) {
          await _pumpApp(
            tester,
            initialLocation: protectedPath,
            repository: _authenticatedRepository(
              _user(
                loginName: '${role.value}-first-login',
                role: role,
                mustChangePassword: true,
              ),
            ),
            surface: AppDeviceSurface.desktop,
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Password change is required before normal access.'),
            findsOneWidget,
          );
          expect(find.text('Unsupported device'), findsNothing);
        }
      }
    });

    testWidgets('bootstrapping shows neutral loading without auth flash', (
      tester,
    ) async {
      final repository = FakeAuthRepository(storedToken: 'token-a');
      final currentUser = Completer<AuthUser>();
      repository.onCurrentUser = () => currentUser.future;

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.login,
        repository: repository,
      );
      await tester.pump();

      expect(find.text('Loading'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
      expect(find.text('Teacher'), findsNothing);

      currentUser.complete(
        _user(loginName: 'teacher01', role: UserRole.teacher),
      );
      await tester.pumpAndSettle();

      expect(find.text('Teacher'), findsOneWidget);
    });
  });

  group('role/device entry routing', () {
    testWidgets('all ten supported role/device combinations route correctly', (
      tester,
    ) async {
      final cases = <_RouteCase>[
        _RouteCase(
          role: UserRole.platformOwner,
          surface: AppDeviceSurface.desktop,
          expectedTitle: 'Platform Owner',
        ),
        _RouteCase(
          role: UserRole.platformOwner,
          surface: AppDeviceSurface.mobile,
          expectedTitle: 'Unsupported device',
        ),
        _RouteCase(
          role: UserRole.institutionAdmin,
          surface: AppDeviceSurface.desktop,
          expectedTitle: 'Institution Admin',
        ),
        _RouteCase(
          role: UserRole.institutionAdmin,
          surface: AppDeviceSurface.mobile,
          expectedTitle: 'Unsupported device',
        ),
        _RouteCase(
          role: UserRole.teacher,
          surface: AppDeviceSurface.desktop,
          expectedTitle: 'Teacher',
        ),
        _RouteCase(
          role: UserRole.teacher,
          surface: AppDeviceSurface.mobile,
          expectedTitle: 'Teacher',
        ),
        _RouteCase(
          role: UserRole.student,
          surface: AppDeviceSurface.desktop,
          expectedTitle: 'Student',
        ),
        _RouteCase(
          role: UserRole.student,
          surface: AppDeviceSurface.mobile,
          expectedTitle: 'Student',
        ),
        _RouteCase(
          role: UserRole.parent,
          surface: AppDeviceSurface.desktop,
          expectedTitle: 'Unsupported device',
        ),
        _RouteCase(
          role: UserRole.parent,
          surface: AppDeviceSurface.mobile,
          expectedTitle: 'Parent',
        ),
      ];

      for (final testCase in cases) {
        await _pumpApp(
          tester,
          initialLocation: AppRoutePaths.login,
          repository: _authenticatedRepository(
            _user(loginName: testCase.role.value, role: testCase.role),
          ),
          surface: testCase.surface,
        );
        await tester.pumpAndSettle();

        expect(find.text(testCase.expectedTitle), findsOneWidget);
      }
    });

    testWidgets('password-complete auth routes redirect to canonical entry', (
      tester,
    ) async {
      for (final authPath in AppRoutePaths.auth) {
        await _pumpApp(
          tester,
          initialLocation: authPath,
          repository: _authenticatedRepository(
            _user(loginName: 'teacher01', role: UserRole.teacher),
          ),
          surface: AppDeviceSurface.desktop,
        );
        await tester.pumpAndSettle();

        expect(find.text('Teacher'), findsOneWidget);
        expect(find.text('Authenticated session ready'), findsNothing);
      }

      for (final authPath in AppRoutePaths.auth) {
        await _pumpApp(
          tester,
          initialLocation: authPath,
          repository: _authenticatedRepository(
            _user(loginName: 'parent01', role: UserRole.parent),
          ),
          surface: AppDeviceSurface.desktop,
        );
        await tester.pumpAndSettle();

        expect(find.text('Unsupported device'), findsOneWidget);
        expect(find.text('Authenticated session ready'), findsNothing);
      }
    });

    testWidgets('supported users never render the wrong role shell', (
      tester,
    ) async {
      final cases = <_WrongRouteCase>[
        _WrongRouteCase(
          user: _user(
            loginName: 'owner01',
            fullName: 'Owner User',
            role: UserRole.platformOwner,
          ),
          surface: AppDeviceSurface.desktop,
          wrongPath: AppRoutePaths.teacher,
          expectedTitle: 'Platform Owner',
          forbiddenTitle: 'Teacher',
        ),
        _WrongRouteCase(
          user: _user(
            loginName: 'admin01',
            fullName: 'Admin User',
            role: UserRole.institutionAdmin,
          ),
          surface: AppDeviceSurface.desktop,
          wrongPath: AppRoutePaths.platformOwner,
          expectedTitle: 'Institution Admin',
          forbiddenTitle: 'Platform Owner',
        ),
        _WrongRouteCase(
          user: _user(
            loginName: 'teacher01',
            fullName: 'Teacher User',
            role: UserRole.teacher,
          ),
          surface: AppDeviceSurface.desktop,
          wrongPath: AppRoutePaths.institutionAdmin,
          expectedTitle: 'Teacher',
          forbiddenTitle: 'Institution Admin',
        ),
        _WrongRouteCase(
          user: _user(
            loginName: 'student01',
            fullName: 'Student User',
            role: UserRole.student,
          ),
          surface: AppDeviceSurface.desktop,
          wrongPath: AppRoutePaths.teacher,
          expectedTitle: 'Student',
          forbiddenTitle: 'Teacher',
        ),
        _WrongRouteCase(
          user: _user(
            loginName: 'parent01',
            fullName: 'Parent User',
            role: UserRole.parent,
          ),
          surface: AppDeviceSurface.mobile,
          wrongPath: AppRoutePaths.student,
          expectedTitle: 'Parent',
          forbiddenTitle: 'Student',
        ),
      ];

      for (final testCase in cases) {
        await _pumpApp(
          tester,
          initialLocation: testCase.wrongPath,
          repository: _authenticatedRepository(testCase.user),
          surface: testCase.surface,
        );
        await tester.pumpAndSettle();

        expect(find.text(testCase.expectedTitle), findsOneWidget);
        expect(find.text(testCase.forbiddenTitle), findsNothing);
      }
    });

    testWidgets('unsupported device combinations stay unsupported', (
      tester,
    ) async {
      final cases = <_UnsupportedRouteCase>[
        _UnsupportedRouteCase(
          user: _user(loginName: 'parent01', role: UserRole.parent),
          surface: AppDeviceSurface.desktop,
          attemptedPaths: const [
            AppRoutePaths.parent,
            AppRoutePaths.student,
            AppRoutePaths.teacher,
          ],
        ),
        _UnsupportedRouteCase(
          user: _user(loginName: 'owner01', role: UserRole.platformOwner),
          surface: AppDeviceSurface.mobile,
          attemptedPaths: const [
            AppRoutePaths.platformOwner,
            AppRoutePaths.teacher,
          ],
        ),
        _UnsupportedRouteCase(
          user: _user(loginName: 'admin01', role: UserRole.institutionAdmin),
          surface: AppDeviceSurface.mobile,
          attemptedPaths: const [
            AppRoutePaths.institutionAdmin,
            AppRoutePaths.teacher,
          ],
        ),
      ];

      for (final testCase in cases) {
        for (final attemptedPath in testCase.attemptedPaths) {
          await _pumpApp(
            tester,
            initialLocation: attemptedPath,
            repository: _authenticatedRepository(testCase.user),
            surface: testCase.surface,
          );
          await tester.pumpAndSettle();

          expect(find.text('Unsupported device'), findsOneWidget);
          expect(
            find.text('This account is not supported on this device.'),
            findsOneWidget,
          );
        }
      }
    });

    testWidgets('viewport size does not decide route authorization', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.login,
        repository: _authenticatedRepository(
          _user(loginName: 'parent01', role: UserRole.parent),
        ),
        surface: AppDeviceSurface.desktop,
      );
      await tester.pumpAndSettle();

      expect(find.text('Unsupported device'), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.login,
        repository: _authenticatedRepository(
          _user(loginName: 'parent01', role: UserRole.parent),
        ),
        surface: AppDeviceSurface.desktop,
      );
      await tester.pumpAndSettle();

      expect(find.text('Unsupported device'), findsOneWidget);
    });
  });

  group('entry shell content and logout', () {
    testWidgets('minimal shells show only current session identity', (
      tester,
    ) async {
      final cases = <_RouteCase>[
        _RouteCase(
          role: UserRole.platformOwner,
          surface: AppDeviceSurface.desktop,
          expectedTitle: 'Platform Owner',
          fullName: 'Platform Owner User',
          shouldShowInstitution: false,
        ),
        _RouteCase(
          role: UserRole.institutionAdmin,
          surface: AppDeviceSurface.desktop,
          expectedTitle: 'Institution Admin',
          fullName: 'Institution Admin User',
        ),
        _RouteCase(
          role: UserRole.teacher,
          surface: AppDeviceSurface.desktop,
          expectedTitle: 'Teacher',
          fullName: 'Teacher User',
        ),
        _RouteCase(
          role: UserRole.student,
          surface: AppDeviceSurface.desktop,
          expectedTitle: 'Student',
          fullName: 'Student User',
        ),
        _RouteCase(
          role: UserRole.parent,
          surface: AppDeviceSurface.mobile,
          expectedTitle: 'Parent',
          fullName: 'Parent User',
        ),
      ];

      for (final testCase in cases) {
        await _pumpApp(
          tester,
          initialLocation: AppRoutePaths.login,
          repository: _authenticatedRepository(
            _user(
              loginName: testCase.role.value,
              fullName: testCase.fullName,
              role: testCase.role,
            ),
          ),
          surface: testCase.surface,
        );
        await tester.pumpAndSettle();

        expect(find.text(testCase.expectedTitle), findsOneWidget);
        expect(find.text('Current user: ${testCase.fullName}'), findsOneWidget);
        expect(find.byKey(const Key('entryLogoutButton')), findsOneWidget);
        if (testCase.shouldShowInstitution) {
          expect(find.text('Institution: Example School'), findsOneWidget);
        } else {
          expect(find.byKey(const Key('entryInstitutionName')), findsNothing);
        }
        if (testCase.role == UserRole.platformOwner) {
          expect(find.text('Dashboard'), findsWidgets);
          expect(find.text('Institutions'), findsWidgets);
        } else if (testCase.role == UserRole.institutionAdmin) {
          expect(
            find.byKey(const Key('institutionAdminShell')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('institutionAdminNavigation')),
            findsOneWidget,
          );
          expect(find.text('Dashboard'), findsWidgets);
          expect(find.text('Users'), findsOneWidget);
          expect(find.text('Institution'), findsOneWidget);
          expect(find.text('Settings'), findsOneWidget);
          expect(find.text('Device: desktop'), findsNothing);
        } else {
          _expectNoFutureFeatureText();
        }
      }
    });

    testWidgets('teacher and student identify desktop and mobile surfaces', (
      tester,
    ) async {
      final cases = <_RouteCase>[
        _RouteCase(
          role: UserRole.teacher,
          surface: AppDeviceSurface.desktop,
          expectedTitle: 'Teacher',
        ),
        _RouteCase(
          role: UserRole.teacher,
          surface: AppDeviceSurface.mobile,
          expectedTitle: 'Teacher',
        ),
        _RouteCase(
          role: UserRole.student,
          surface: AppDeviceSurface.desktop,
          expectedTitle: 'Student',
        ),
        _RouteCase(
          role: UserRole.student,
          surface: AppDeviceSurface.mobile,
          expectedTitle: 'Student',
        ),
      ];

      for (final testCase in cases) {
        await _pumpApp(
          tester,
          initialLocation: AppRoutePaths.login,
          repository: _authenticatedRepository(
            _user(loginName: testCase.role.value, role: testCase.role),
          ),
          surface: testCase.surface,
        );
        await tester.pumpAndSettle();

        expect(find.text(testCase.expectedTitle), findsOneWidget);
        expect(find.text('Device: ${testCase.surface.label}'), findsOneWidget);
      }
    });

    testWidgets('logout clears shell even when backend logout fails', (
      tester,
    ) async {
      final repository = _authenticatedRepository(
        _user(
          loginName: 'teacher-a',
          fullName: 'Teacher A',
          role: UserRole.teacher,
        ),
      );
      repository.onSignOut = () async {
        throw ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.connection,
            message: 'Logout transport failed.',
          ),
        );
      };

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.teacher,
        repository: repository,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('entryLogoutButton')));
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 1);
      expect(find.text('Login'), findsOneWidget);
      expect(find.textContaining('Teacher A'), findsNothing);
    });
  });

  group('session isolation routing', () {
    testWidgets('login failure remains visible after auth state refresh', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      repository.onSignIn = (_, _) async {
        throw ApiRequestException(
          ApiFailure.fromServerError(
            statusCode: 401,
            error: ApiErrorResponse(
              message: 'The provided login credentials are invalid.',
              code: ApiErrorCodes.invalidCredentials,
              fieldErrors: const {},
              requestId: null,
            ),
          ),
        );
      };

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.login,
        repository: repository,
      );
      await tester.pumpAndSettle();

      await _submitLogin(tester, login: 'teacher01');

      expect(find.text('Login or password is incorrect.'), findsOneWidget);
      expect(find.text('Teacher'), findsNothing);
    });

    testWidgets('same-role account switch shows only new identity', (
      tester,
    ) async {
      final repository = _authenticatedRepository(
        _user(
          loginName: 'teacher-a',
          fullName: 'Teacher A',
          role: UserRole.teacher,
        ),
      );

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.teacher,
        repository: repository,
      );
      await tester.pumpAndSettle();
      expect(find.text('Current user: Teacher A'), findsOneWidget);

      await tester.tap(find.byKey(const Key('entryLogoutButton')));
      await tester.pumpAndSettle();

      repository.onSignIn = (_, _) async => _user(
        loginName: 'teacher-b',
        fullName: 'Teacher B',
        role: UserRole.teacher,
      );
      await _submitLogin(tester, login: 'teacher-b');

      expect(find.text('Teacher'), findsOneWidget);
      expect(find.text('Current user: Teacher B'), findsOneWidget);
      expect(find.textContaining('Teacher A'), findsNothing);
    });

    testWidgets('cross-role account switch routes to new user shell', (
      tester,
    ) async {
      final repository = _authenticatedRepository(
        _user(
          loginName: 'teacher-a',
          fullName: 'Teacher A',
          role: UserRole.teacher,
        ),
      );

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.teacher,
        repository: repository,
      );
      await tester.pumpAndSettle();
      expect(find.text('Teacher'), findsOneWidget);

      await tester.tap(find.byKey(const Key('entryLogoutButton')));
      await tester.pumpAndSettle();

      repository.onSignIn = (_, _) async => _user(
        loginName: 'student-b',
        fullName: 'Student B',
        role: UserRole.student,
      );
      await _submitLogin(tester, login: 'student-b');

      expect(find.text('Student'), findsOneWidget);
      expect(find.text('Current user: Student B'), findsOneWidget);
      expect(find.text('Teacher'), findsNothing);
      expect(find.textContaining('Teacher A'), findsNothing);
    });

    testWidgets(
      'supported and unsupported account switches do not leak state',
      (tester) async {
        final repository = _authenticatedRepository(
          _user(
            loginName: 'parent-a',
            fullName: 'Parent A',
            role: UserRole.parent,
          ),
        );

        await _pumpApp(
          tester,
          initialLocation: AppRoutePaths.parent,
          repository: repository,
          surface: AppDeviceSurface.desktop,
        );
        await tester.pumpAndSettle();
        expect(find.text('Unsupported device'), findsOneWidget);

        await tester.tap(find.byKey(const Key('entryLogoutButton')));
        await tester.pumpAndSettle();

        repository.onSignIn = (_, _) async => _user(
          loginName: 'teacher-b',
          fullName: 'Teacher B',
          role: UserRole.teacher,
        );
        await _submitLogin(tester, login: 'teacher-b');

        expect(find.text('Teacher'), findsOneWidget);
        expect(find.text('Current user: Teacher B'), findsOneWidget);
        expect(find.textContaining('Parent A'), findsNothing);

        await tester.tap(find.byKey(const Key('entryLogoutButton')));
        await tester.pumpAndSettle();

        repository.onSignIn = (_, _) async => _user(
          loginName: 'parent-b',
          fullName: 'Parent B',
          role: UserRole.parent,
        );
        await _submitLogin(tester, login: 'parent-b');

        expect(find.text('Unsupported device'), findsOneWidget);
        expect(find.text('Current user: Parent B'), findsOneWidget);
        expect(find.textContaining('Teacher B'), findsNothing);
      },
    );

    testWidgets('delayed prior /auth/me cannot restore old shell', (
      tester,
    ) async {
      final repository = FakeAuthRepository(storedToken: 'token-a');
      final currentUserA = Completer<AuthUser>();
      repository.onCurrentUser = () => currentUserA.future;
      final container = await _pumpAppWithContainer(
        tester,
        initialLocation: AppRoutePaths.login,
        repository: repository,
      );
      final controller = container.read(authSessionControllerProvider.notifier);
      await tester.pump();

      await controller.signOut();
      repository.onSignIn = (_, _) async => _user(
        loginName: 'student-b',
        fullName: 'Student B',
        role: UserRole.student,
      );
      await controller.signIn(login: 'student-b', password: 'secret');
      await tester.pumpAndSettle();

      currentUserA.complete(
        _user(
          loginName: 'teacher-a',
          fullName: 'Teacher A',
          role: UserRole.teacher,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Student'), findsOneWidget);
      expect(find.text('Current user: Student B'), findsOneWidget);
      expect(find.text('Teacher'), findsNothing);
      expect(find.textContaining('Teacher A'), findsNothing);
    });

    testWidgets('global authentication invalidation clears current shell', (
      tester,
    ) async {
      final signal = SessionInvalidationSignal();
      addTearDown(signal.dispose);
      final repository = _authenticatedRepository(
        _user(
          loginName: 'teacher-a',
          fullName: 'Teacher A',
          role: UserRole.teacher,
        ),
        tokenVersion: 1,
      );

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.teacher,
        repository: repository,
        signal: signal,
      );
      await tester.pumpAndSettle();

      signal.authenticationRequired(tokenVersion: 1);
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.textContaining('Teacher A'), findsNothing);
      expect(repository.clearTokenIfVersionCalls, [1]);
    });
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
  required FakeAuthRepository repository,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
  SessionInvalidationSignal? signal,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appInitialLocationProvider.overrideWithValue(initialLocation),
        authRepositoryProvider.overrideWithValue(repository),
        appDeviceSurfaceProvider.overrideWithValue(surface),
        platformDashboardRepositoryProvider.overrideWithValue(
          FakePlatformDashboardRepository(),
        ),
        platformInstitutionListRepositoryProvider.overrideWithValue(
          FakePlatformInstitutionListRepository(),
        ),
        if (signal != null)
          sessionInvalidationSignalProvider.overrideWithValue(signal),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<ProviderContainer> _pumpAppWithContainer(
  WidgetTester tester, {
  required String initialLocation,
  required FakeAuthRepository repository,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) async {
  final container = ProviderContainer(
    overrides: [
      appInitialLocationProvider.overrideWithValue(initialLocation),
      authRepositoryProvider.overrideWithValue(repository),
      appDeviceSurfaceProvider.overrideWithValue(surface),
      platformDashboardRepositoryProvider.overrideWithValue(
        FakePlatformDashboardRepository(),
      ),
      platformInstitutionListRepositoryProvider.overrideWithValue(
        FakePlatformInstitutionListRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();

  return container;
}

Future<void> _submitLogin(WidgetTester tester, {required String login}) async {
  await tester.enterText(find.byKey(const Key('loginField')), login);
  await tester.enterText(find.byKey(const Key('passwordField')), 'secret');
  await tester.tap(find.byKey(const Key('signInButton')));
  await tester.pumpAndSettle();
}

FakeAuthRepository _authenticatedRepository(
  AuthUser user, {
  int tokenVersion = 0,
}) {
  return FakeAuthRepository(
    storedToken: 'token-a',
    tokenVersion: tokenVersion,
    onCurrentUser: () async => user,
  );
}

AuthUser _user({
  required String loginName,
  required UserRole role,
  String? fullName,
  bool mustChangePassword = false,
}) {
  return AuthUser(
    id: '$loginName-id',
    institutionId: role == UserRole.platformOwner ? null : 'institution-1',
    role: role,
    fullName: fullName ?? '$loginName User',
    loginName: loginName,
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: mustChangePassword,
    institution: role == UserRole.platformOwner
        ? null
        : const AuthInstitution(
            id: 'institution-1',
            name: 'Example School',
            status: 'active',
            timezone: 'Asia/Tashkent',
          ),
  );
}

void _expectNoFutureFeatureText() {
  expect(find.text('Dashboard'), findsNothing);
  expect(find.text('Groups'), findsNothing);
  expect(find.text('Topics'), findsNothing);
  expect(find.text('Homework'), findsNothing);
  expect(find.text('Blitz'), findsNothing);
  expect(find.text('Reports'), findsNothing);
}

class _RouteCase {
  const _RouteCase({
    required this.role,
    required this.surface,
    required this.expectedTitle,
    this.fullName = 'Test User',
    this.shouldShowInstitution = true,
  });

  final UserRole role;
  final AppDeviceSurface surface;
  final String expectedTitle;
  final String fullName;
  final bool shouldShowInstitution;
}

class _WrongRouteCase {
  const _WrongRouteCase({
    required this.user,
    required this.surface,
    required this.wrongPath,
    required this.expectedTitle,
    required this.forbiddenTitle,
  });

  final AuthUser user;
  final AppDeviceSurface surface;
  final String wrongPath;
  final String expectedTitle;
  final String forbiddenTitle;
}

class _UnsupportedRouteCase {
  const _UnsupportedRouteCase({
    required this.user,
    required this.surface,
    required this.attemptedPaths,
  });

  final AuthUser user;
  final AppDeviceSurface surface;
  final List<String> attemptedPaths;
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.storedToken,
    this.tokenVersion = 0,
    this.onCurrentUser,
  });

  String? storedToken;
  int tokenVersion;

  Future<AuthUser> Function()? onCurrentUser;
  Future<AuthUser> Function(String login, String password)? onSignIn;
  Future<void> Function()? onSignOut;

  final signInCalls = <({String login, String password})>[];
  final clearTokenIfVersionCalls = <int>[];
  var currentUserCalls = 0;
  var signOutCalls = 0;
  var clearTokenCalls = 0;

  @override
  Future<AuthUser> signIn({required String login, required String password}) {
    signInCalls.add((login: login, password: password));

    return onSignIn?.call(login, password) ??
        Future.value(_user(loginName: login, role: UserRole.teacher));
  }

  @override
  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    return _user(loginName: 'teacher01', role: UserRole.teacher);
  }

  @override
  Future<AuthUser> currentUser() {
    currentUserCalls += 1;

    return onCurrentUser?.call() ??
        Future.value(_user(loginName: 'teacher01', role: UserRole.teacher));
  }

  @override
  Future<void> signOut() {
    signOutCalls += 1;
    storedToken = null;

    return onSignOut?.call() ?? Future.value();
  }

  @override
  Future<String?> readStoredToken() async {
    return storedToken;
  }

  @override
  Future<void> clearToken() async {
    clearTokenCalls += 1;
    storedToken = null;
    tokenVersion += 1;
  }

  @override
  Future<bool> clearTokenIfVersion(int tokenVersion) async {
    clearTokenIfVersionCalls.add(tokenVersion);

    if (this.tokenVersion != tokenVersion) {
      return false;
    }

    storedToken = null;
    this.tokenVersion += 1;

    return true;
  }
}

class FakePlatformDashboardRepository implements PlatformDashboardRepository {
  var fetchCalls = 0;

  @override
  Future<PlatformDashboard> fetchDashboard() async {
    fetchCalls += 1;

    return PlatformDashboard(
      institutions: const PlatformInstitutionCounts(
        total: 20,
        active: 18,
        inactive: 2,
      ),
      users: const PlatformUserCounts(total: 2800, active: 2720),
      recentInstitutions: [
        RecentPlatformInstitution(
          id: '00000000-0000-0000-0000-000000000001',
          name: 'Example School',
          type: PlatformInstitutionType.school,
          status: PlatformInstitutionStatus.active,
          createdAt: DateTime.utc(2026, 8, 1, 10),
        ),
      ],
    );
  }
}

class FakePlatformInstitutionListRepository
    implements PlatformInstitutionListRepository {
  @override
  Future<PlatformInstitutionListPage> fetchInstitutions(
    PlatformInstitutionListQuery query,
  ) async {
    return PlatformInstitutionListPage(
      institutions: [
        PlatformInstitutionSummary(
          id: '00000000-0000-0000-0000-000000000001',
          name: 'Example School',
          type: PlatformInstitutionType.school,
          status: PlatformInstitutionStatus.active,
          contactEmail: 'info@example.uz',
          contactPhone: '+998901234567',
          createdAt: DateTime.utc(2026, 8, 7, 15),
          updatedAt: DateTime.utc(2026, 8, 7, 16),
          userCounts: const PlatformInstitutionUserCounts(
            total: 42,
            active: 40,
          ),
        ),
      ],
      pagination: const PlatformInstitutionPagination(
        page: 1,
        perPage: 20,
        total: 1,
        lastPage: 1,
      ),
    );
  }
}
