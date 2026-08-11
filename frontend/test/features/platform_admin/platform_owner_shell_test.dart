import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/session_invalidation_signal.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard_repository.dart';
import 'package:testlabuz_client/features/platform_admin/presentation/platform_owner_shell.dart';

void main() {
  group('Platform Owner direct routing', () {
    testWidgets('desktop owner enters Dashboard route in the shell', (
      tester,
    ) async {
      final repository = _authenticatedRepository(
        _user(
          loginName: 'owner-a',
          fullName: 'Owner A',
          role: UserRole.platformOwner,
        ),
      );

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwner,
        repository: repository,
      );
      await tester.pumpAndSettle();

      _expectPlatformOwnerDestination(
        tester,
        path: AppRoutePaths.platformOwner,
        destination: PlatformOwnerShellDestination.dashboard,
        fullName: 'Owner A',
      );
      expect(find.byKey(const Key('platformDashboardData')), findsOneWidget);
      expect(repository.currentUserCalls, 1);
    });

    testWidgets('desktop owner enters Institutions route in the same shell', (
      tester,
    ) async {
      final repository = _authenticatedRepository(
        _user(
          loginName: 'owner-a',
          fullName: 'Owner A',
          role: UserRole.platformOwner,
        ),
      );

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwnerInstitutions,
        repository: repository,
      );
      await tester.pumpAndSettle();

      _expectPlatformOwnerDestination(
        tester,
        path: AppRoutePaths.platformOwnerInstitutions,
        destination: PlatformOwnerShellDestination.institutions,
        fullName: 'Owner A',
      );
      expect(
        find.byKey(const Key('platformOwnerInstitutionsPlaceholder')),
        findsOneWidget,
      );
      expect(repository.currentUserCalls, 1);
    });

    testWidgets('direct Institutions entry is not reset after rebuild', (
      tester,
    ) async {
      final repository = _authenticatedRepository(
        _user(
          loginName: 'owner-a',
          fullName: 'Owner A',
          role: UserRole.platformOwner,
        ),
      );
      final container = await _pumpAppWithContainer(
        tester,
        initialLocation: AppRoutePaths.platformOwnerInstitutions,
        repository: repository,
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestLabUzApp(),
        ),
      );
      await tester.pumpAndSettle();

      _expectPlatformOwnerDestination(
        tester,
        path: AppRoutePaths.platformOwnerInstitutions,
        destination: PlatformOwnerShellDestination.institutions,
        fullName: 'Owner A',
      );
    });

    testWidgets('unknown Platform Owner children do not render the shell', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: '/platform-owner/settings',
        repository: _authenticatedRepository(
          _user(loginName: 'owner-a', role: UserRole.platformOwner),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
      expect(find.byKey(const Key('platformOwnerNavigation')), findsNothing);
      expect(find.text('Dashboard'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Platform Owner guard matrix', () {
    testWidgets('unauthenticated owner routes resolve to login', (
      tester,
    ) async {
      for (final route in _platformOwnerRoutes) {
        await _pumpApp(
          tester,
          initialLocation: route,
          repository: FakeAuthRepository(),
        );
        await tester.pumpAndSettle();

        expect(_currentPath(tester), AppRoutePaths.login);
        expect(find.text('Login'), findsOneWidget);
        expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
      }
    });

    testWidgets('must-change users resolve to change password first', (
      tester,
    ) async {
      for (final route in _platformOwnerRoutes) {
        for (final role in UserRole.values) {
          await _pumpApp(
            tester,
            initialLocation: route,
            repository: _authenticatedRepository(
              _user(
                loginName: '${role.value}-first-login',
                role: role,
                mustChangePassword: true,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(_currentPath(tester), AppRoutePaths.changePassword);
          expect(
            find.text('Password change is required before normal access.'),
            findsOneWidget,
          );
          expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
        }
      }
    });

    testWidgets('wrong role and device attempts never render owner shell', (
      tester,
    ) async {
      final cases = <_GuardCase>[
        _GuardCase(
          user: _user(loginName: 'owner', role: UserRole.platformOwner),
          surface: AppDeviceSurface.mobile,
          expectedPath: AppRoutePaths.unsupportedDevice,
          expectedText: 'Unsupported device',
        ),
        _GuardCase(
          user: _user(loginName: 'owner', role: UserRole.platformOwner),
          surface: AppDeviceSurface.unsupported,
          expectedPath: AppRoutePaths.unsupportedDevice,
          expectedText: 'Unsupported device',
        ),
        _GuardCase(
          user: _user(loginName: 'admin', role: UserRole.institutionAdmin),
          surface: AppDeviceSurface.desktop,
          expectedPath: AppRoutePaths.institutionAdmin,
          expectedText: 'Institution Admin',
        ),
        _GuardCase(
          user: _user(loginName: 'teacher', role: UserRole.teacher),
          surface: AppDeviceSurface.desktop,
          expectedPath: AppRoutePaths.teacher,
          expectedText: 'Teacher',
        ),
        _GuardCase(
          user: _user(loginName: 'teacher', role: UserRole.teacher),
          surface: AppDeviceSurface.mobile,
          expectedPath: AppRoutePaths.teacher,
          expectedText: 'Teacher',
        ),
        _GuardCase(
          user: _user(loginName: 'student', role: UserRole.student),
          surface: AppDeviceSurface.desktop,
          expectedPath: AppRoutePaths.student,
          expectedText: 'Student',
        ),
        _GuardCase(
          user: _user(loginName: 'student', role: UserRole.student),
          surface: AppDeviceSurface.mobile,
          expectedPath: AppRoutePaths.student,
          expectedText: 'Student',
        ),
        _GuardCase(
          user: _user(loginName: 'parent', role: UserRole.parent),
          surface: AppDeviceSurface.mobile,
          expectedPath: AppRoutePaths.parent,
          expectedText: 'Parent',
        ),
        _GuardCase(
          user: _user(loginName: 'parent', role: UserRole.parent),
          surface: AppDeviceSurface.desktop,
          expectedPath: AppRoutePaths.unsupportedDevice,
          expectedText: 'Unsupported device',
        ),
      ];

      for (final route in _platformOwnerRoutes) {
        for (final testCase in cases) {
          await _pumpApp(
            tester,
            initialLocation: route,
            repository: _authenticatedRepository(testCase.user),
            surface: testCase.surface,
          );
          await tester.pumpAndSettle();

          expect(_currentPath(tester), testCase.expectedPath);
          expect(find.text(testCase.expectedText), findsOneWidget);
          expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
        }
      }
    });

    testWidgets('Platform Owner is not a cross-role bypass', (tester) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.teacher,
        repository: _authenticatedRepository(
          _user(
            loginName: 'owner-a',
            fullName: 'Owner A',
            role: UserRole.platformOwner,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_currentPath(tester), AppRoutePaths.platformOwner);
      expect(find.byKey(const Key('platformOwnerShell')), findsOneWidget);
      expect(find.text('Teacher'), findsNothing);
    });
  });

  group('Platform Owner shell content and navigation', () {
    testWidgets('shell shows only approved identity and destinations', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwnerInstitutions,
        repository: _authenticatedRepository(
          _user(
            loginName: 'owner-a',
            fullName: 'Owner A',
            role: UserRole.platformOwner,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navigation = find.byKey(const Key('platformOwnerNavigation'));
      expect(find.text('TestLabUz'), findsOneWidget);
      expect(
        find.descendant(of: navigation, matching: find.text('Dashboard')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: navigation, matching: find.text('Institutions')),
        findsOneWidget,
      );
      expect(find.text('Current user: Owner A'), findsOneWidget);
      expect(find.text('Platform Owner'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.byTooltip('Dashboard'), findsOneWidget);
      expect(find.byTooltip('Institutions'), findsOneWidget);
      expect(find.text('Institution: Example School'), findsNothing);
      expect(find.text('Example School'), findsNothing);
      _expectNoLaterTaskText();
    });

    testWidgets('navigation updates URI, selection, reselect, and back', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwner,
        repository: _authenticatedRepository(
          _user(
            loginName: 'owner-a',
            fullName: 'Owner A',
            role: UserRole.platformOwner,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_router(tester).canPop(), isFalse);
      await _selectDestination(tester, PlatformOwnerShellDestination.dashboard);
      await tester.pumpAndSettle();
      expect(_currentPath(tester), AppRoutePaths.platformOwner);
      expect(_router(tester).canPop(), isFalse);

      await _selectDestination(
        tester,
        PlatformOwnerShellDestination.institutions,
      );
      await tester.pumpAndSettle();
      _expectPlatformOwnerDestination(
        tester,
        path: AppRoutePaths.platformOwnerInstitutions,
        destination: PlatformOwnerShellDestination.institutions,
        fullName: 'Owner A',
      );

      await _selectDestination(
        tester,
        PlatformOwnerShellDestination.institutions,
      );
      await tester.pumpAndSettle();
      expect(_currentPath(tester), AppRoutePaths.platformOwnerInstitutions);

      await _selectDestination(tester, PlatformOwnerShellDestination.dashboard);
      await tester.pumpAndSettle();
      _expectPlatformOwnerDestination(
        tester,
        path: AppRoutePaths.platformOwner,
        destination: PlatformOwnerShellDestination.dashboard,
        fullName: 'Owner A',
      );

      _router(tester).pop();
      await tester.pumpAndSettle();
      _expectPlatformOwnerDestination(
        tester,
        path: AppRoutePaths.platformOwnerInstitutions,
        destination: PlatformOwnerShellDestination.institutions,
        fullName: 'Owner A',
      );
    });

    testWidgets('Dashboard data request is scoped to Dashboard destination', (
      tester,
    ) async {
      final repository = _authenticatedRepository(
        _user(
          loginName: 'owner-a',
          fullName: 'Owner A',
          role: UserRole.platformOwner,
        ),
      );
      final dashboardRepository = FakePlatformDashboardRepository();

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwnerInstitutions,
        repository: repository,
        dashboardRepository: dashboardRepository,
      );
      await tester.pumpAndSettle();
      expect(repository.currentUserCalls, 1);
      expect(dashboardRepository.fetchCalls, 0);

      await _selectDestination(tester, PlatformOwnerShellDestination.dashboard);
      await tester.pumpAndSettle();
      expect(dashboardRepository.fetchCalls, 1);
      await _selectDestination(tester, PlatformOwnerShellDestination.dashboard);
      await tester.pumpAndSettle();

      expect(dashboardRepository.fetchCalls, 1);
      expect(repository.currentUserCalls, 1);
      expect(repository.signInCalls, isEmpty);
      expect(repository.changePasswordCalls, isEmpty);
    });
  });

  group('Platform Owner compact and wide layout', () {
    testWidgets('800x600 desktop layout has accessible destinations', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwner,
        repository: _authenticatedRepository(
          _user(loginName: 'owner-a', role: UserRole.platformOwner),
        ),
      );
      await tester.pumpAndSettle();

      _expectPlatformOwnerDestination(
        tester,
        path: AppRoutePaths.platformOwner,
        destination: PlatformOwnerShellDestination.dashboard,
      );
      expect(find.byTooltip('Dashboard'), findsOneWidget);
      expect(find.byTooltip('Institutions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1440x900 desktop layout has accessible destinations', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwnerInstitutions,
        repository: _authenticatedRepository(
          _user(loginName: 'owner-a', role: UserRole.platformOwner),
        ),
      );
      await tester.pumpAndSettle();

      _expectPlatformOwnerDestination(
        tester,
        path: AppRoutePaths.platformOwnerInstitutions,
        destination: PlatformOwnerShellDestination.institutions,
      );
      expect(find.byTooltip('Dashboard'), findsOneWidget);
      expect(find.byTooltip('Institutions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('viewport width does not change device authorization', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwner,
        repository: _authenticatedRepository(
          _user(loginName: 'owner-a', role: UserRole.platformOwner),
        ),
        surface: AppDeviceSurface.mobile,
      );
      await tester.pumpAndSettle();

      expect(_currentPath(tester), AppRoutePaths.unsupportedDevice);
      expect(find.text('Unsupported device'), findsOneWidget);
      expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
    });
  });

  group('Platform Owner logout and session isolation', () {
    testWidgets('logout removes shell from each destination', (tester) async {
      for (final route in _platformOwnerRoutes) {
        final repository = _authenticatedRepository(
          _user(
            loginName: 'owner-a',
            fullName: 'Owner A',
            role: UserRole.platformOwner,
          ),
        );

        await _pumpApp(tester, initialLocation: route, repository: repository);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('entryLogoutButton')));
        await tester.pumpAndSettle();

        expect(repository.signOutCalls, 1);
        expect(_currentPath(tester), AppRoutePaths.login);
        expect(find.text('Login'), findsOneWidget);
        expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
        expect(find.textContaining('Owner A'), findsNothing);
      }
    });

    testWidgets('backend logout failure cannot restore owner shell', (
      tester,
    ) async {
      final repository = _authenticatedRepository(
        _user(
          loginName: 'owner-a',
          fullName: 'Owner A',
          role: UserRole.platformOwner,
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
        initialLocation: AppRoutePaths.platformOwnerInstitutions,
        repository: repository,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('entryLogoutButton')));
      await tester.pumpAndSettle();

      expect(_currentPath(tester), AppRoutePaths.login);
      expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
      expect(find.textContaining('Owner A'), findsNothing);
    });

    testWidgets('global authentication invalidation removes owner shell', (
      tester,
    ) async {
      final signal = SessionInvalidationSignal();
      addTearDown(signal.dispose);
      final repository = _authenticatedRepository(
        _user(
          loginName: 'owner-a',
          fullName: 'Owner A',
          role: UserRole.platformOwner,
        ),
        tokenVersion: 1,
      );

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwnerInstitutions,
        repository: repository,
        signal: signal,
      );
      await tester.pumpAndSettle();

      signal.authenticationRequired(tokenVersion: 1);
      await tester.pumpAndSettle();

      expect(repository.clearTokenIfVersionCalls, [1]);
      expect(_currentPath(tester), AppRoutePaths.login);
      expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
      expect(find.textContaining('Owner A'), findsNothing);
    });

    testWidgets('Platform Owner A to Platform Owner B exposes only B', (
      tester,
    ) async {
      final repository = _authenticatedRepository(
        _user(
          loginName: 'owner-a',
          fullName: 'Owner A',
          role: UserRole.platformOwner,
        ),
      );

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwnerInstitutions,
        repository: repository,
      );
      await tester.pumpAndSettle();
      expect(find.text('Current user: Owner A'), findsOneWidget);

      await tester.tap(find.byKey(const Key('entryLogoutButton')));
      await tester.pumpAndSettle();

      repository.onSignIn = (_, _) async => _user(
        loginName: 'owner-b',
        fullName: 'Owner B',
        role: UserRole.platformOwner,
      );
      await _submitLogin(tester, login: 'owner-b');

      _expectPlatformOwnerDestination(
        tester,
        path: AppRoutePaths.platformOwner,
        destination: PlatformOwnerShellDestination.dashboard,
        fullName: 'Owner B',
      );
      expect(find.textContaining('Owner A'), findsNothing);
    });

    testWidgets('Platform Owner A to Institution Admin B removes owner shell', (
      tester,
    ) async {
      final repository = _authenticatedRepository(
        _user(
          loginName: 'owner-a',
          fullName: 'Owner A',
          role: UserRole.platformOwner,
        ),
      );

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwner,
        repository: repository,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('entryLogoutButton')));
      await tester.pumpAndSettle();

      repository.onSignIn = (_, _) async => _user(
        loginName: 'admin-b',
        fullName: 'Admin B',
        role: UserRole.institutionAdmin,
      );
      await _submitLogin(tester, login: 'admin-b');

      expect(_currentPath(tester), AppRoutePaths.institutionAdmin);
      expect(find.text('Institution Admin'), findsOneWidget);
      expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
      expect(find.textContaining('Owner A'), findsNothing);
    });
  });
}

const _platformOwnerRoutes = <String>[
  AppRoutePaths.platformOwner,
  AppRoutePaths.platformOwnerInstitutions,
];

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
  required FakeAuthRepository repository,
  FakePlatformDashboardRepository? dashboardRepository,
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
          dashboardRepository ?? FakePlatformDashboardRepository(),
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
  FakePlatformDashboardRepository? dashboardRepository,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) async {
  final container = ProviderContainer(
    overrides: [
      appInitialLocationProvider.overrideWithValue(initialLocation),
      authRepositoryProvider.overrideWithValue(repository),
      appDeviceSurfaceProvider.overrideWithValue(surface),
      platformDashboardRepositoryProvider.overrideWithValue(
        dashboardRepository ?? FakePlatformDashboardRepository(),
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

void _expectPlatformOwnerDestination(
  WidgetTester tester, {
  required String path,
  required PlatformOwnerShellDestination destination,
  String fullName = 'owner-a User',
}) {
  expect(_currentPath(tester), path);
  expect(find.byKey(const Key('platformOwnerShell')), findsOneWidget);
  expect(find.byKey(const Key('platformOwnerNavigation')), findsOneWidget);
  expect(find.text('Current user: $fullName'), findsOneWidget);
  expect(
    destination == PlatformOwnerShellDestination.dashboard
        ? find.byKey(const Key('platformDashboardData'))
        : find.byKey(Key('platformOwner${destination.label}Placeholder')),
    findsOneWidget,
  );
  expect(
    find.widgetWithText(NavigationRail, destination.label),
    findsOneWidget,
  );
  expect(
    tester
        .widget<NavigationRail>(
          find.byKey(const Key('platformOwnerNavigation')),
        )
        .selectedIndex,
    PlatformOwnerShellDestination.values.indexOf(destination),
  );
}

GoRouter _router(WidgetTester tester) {
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

String _currentPath(WidgetTester tester) {
  return _router(tester).routeInformationProvider.value.uri.path;
}

Future<void> _submitLogin(WidgetTester tester, {required String login}) async {
  await tester.enterText(find.byKey(const Key('loginField')), login);
  await tester.enterText(find.byKey(const Key('passwordField')), 'secret');
  await tester.tap(find.byKey(const Key('signInButton')));
  await tester.pumpAndSettle();
}

Future<void> _selectDestination(
  WidgetTester tester,
  PlatformOwnerShellDestination destination,
) async {
  final rail = tester.widget<NavigationRail>(
    find.byKey(const Key('platformOwnerNavigation')),
  );
  expect(rail.onDestinationSelected, isNotNull);
  if (_currentPath(tester) == destination.path) {
    return;
  }

  _router(tester).push(destination.path);
}

void _expectNoLaterTaskText() {
  expect(find.text('Create Institution'), findsNothing);
  expect(find.text('Edit Institution'), findsNothing);
  expect(find.text('Activate'), findsNothing);
  expect(find.text('Deactivate'), findsNothing);
  expect(find.text('Institution Admins'), findsNothing);
  expect(find.text('Settings'), findsNothing);
  expect(find.text('Statistics'), findsNothing);
  expect(find.text('Support'), findsNothing);
  expect(find.text('Issues'), findsNothing);
  expect(find.text('Billing'), findsNothing);
  expect(find.text('Licensing'), findsNothing);
  expect(find.text('Audit'), findsNothing);
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

class _GuardCase {
  const _GuardCase({
    required this.user,
    required this.surface,
    required this.expectedPath,
    required this.expectedText,
  });

  final AuthUser user;
  final AppDeviceSurface surface;
  final String expectedPath;
  final String expectedText;
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
  final changePasswordCalls = <ChangePasswordCall>[];
  final clearTokenIfVersionCalls = <int>[];
  var currentUserCalls = 0;
  var signOutCalls = 0;
  var clearTokenCalls = 0;

  @override
  Future<AuthUser> currentUser() {
    currentUserCalls += 1;

    return onCurrentUser?.call() ??
        Future.value(_user(loginName: 'owner-a', role: UserRole.platformOwner));
  }

  @override
  Future<AuthUser> signIn({required String login, required String password}) {
    signInCalls.add((login: login, password: password));

    return onSignIn?.call(login, password) ??
        Future.value(_user(loginName: login, role: UserRole.platformOwner));
  }

  @override
  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) {
    changePasswordCalls.add(
      ChangePasswordCall(
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirmation: newPasswordConfirmation,
      ),
    );

    return Future.value(
      _user(loginName: 'owner-a', role: UserRole.platformOwner),
    );
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
  FakePlatformDashboardRepository({this.onFetch});

  Future<PlatformDashboard> Function()? onFetch;
  var fetchCalls = 0;

  @override
  Future<PlatformDashboard> fetchDashboard() {
    fetchCalls += 1;

    return onFetch?.call() ?? Future.value(_dashboard());
  }
}

PlatformDashboard _dashboard() {
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

class ChangePasswordCall {
  const ChangePasswordCall({
    required this.currentPassword,
    required this.newPassword,
    required this.newPasswordConfirmation,
  });

  final String currentPassword;
  final String newPassword;
  final String newPasswordConfirmation;
}
