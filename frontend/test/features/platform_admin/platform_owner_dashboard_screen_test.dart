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
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard_repository.dart';

void main() {
  group('PlatformOwnerDashboardScreen', () {
    testWidgets('keeps shell visible while loading with no fake data', (
      tester,
    ) async {
      final dashboardCompleter = Completer<PlatformDashboard>();
      final dashboardRepository = FakePlatformDashboardRepository(
        onFetch: (_) => dashboardCompleter.future,
      );

      await _pumpApp(
        tester,
        authRepository: _authenticatedRepository(_owner('owner-a')),
        dashboardRepository: dashboardRepository,
      );
      await tester.pump();

      expect(find.byKey(const Key('platformOwnerShell')), findsOneWidget);
      expect(find.text('Current user: owner-a User'), findsOneWidget);
      expect(find.byKey(const Key('platformDashboardLoading')), findsOneWidget);
      expect(find.text('Total institutions'), findsNothing);
      expect(find.text('Example School'), findsNothing);
      expect(dashboardRepository.fetchCalls, 1);
    });

    testWidgets('shows five exact KPIs and ordered approved recent fields', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        authRepository: _authenticatedRepository(_owner('owner-a')),
        dashboardRepository: FakePlatformDashboardRepository(
          onFetch: (_) async => _dashboard(
            recentInstitutions: [
              _recentInstitution(
                name: 'Newest School',
                type: PlatformInstitutionType.university,
                status: PlatformInstitutionStatus.active,
                createdAt: DateTime.utc(2026, 8, 2, 9, 15),
              ),
              _recentInstitution(
                id: '00000000-0000-0000-0000-000000000002',
                name: 'Older Center',
                type: PlatformInstitutionType.learningCenter,
                status: PlatformInstitutionStatus.inactive,
                createdAt: DateTime.utc(2026, 8, 1, 10),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('platformDashboardData')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('platformDashboardKpis')),
          matching: find.byType(Card),
        ),
        findsNWidgets(5),
      );
      _expectKpi('Total institutions', '20');
      _expectKpi('Active institutions', '18');
      _expectKpi('Inactive institutions', '2');
      _expectKpi('Total users', '2800');
      _expectKpi('Active users', '2720');
      expect(find.text('Online users'), findsNothing);
      expect(find.text('Logged-in users'), findsNothing);
      expect(find.text('Currently eligible users'), findsNothing);

      expect(
        find.descendant(
          of: find.byKey(const Key('platformDashboardRecentRow0')),
          matching: find.text('Newest School'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('platformDashboardRecentRow0')),
          matching: find.text('University'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('platformDashboardRecentRow0')),
          matching: find.text('Active'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('platformDashboardRecentRow0')),
          matching: find.text('2026-08-02 09:15 UTC'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('platformDashboardRecentRow1')),
          matching: find.text('Older Center'),
        ),
        findsOneWidget,
      );
      expect(find.text('00000000-0000-0000-0000-000000000002'), findsNothing);
      expect(find.text('contact@example.test'), findsNothing);
      expect(find.text('Protected User'), findsNothing);
      _expectNoLaterScopeText();
    });

    testWidgets(
      'shows Institution-empty state with real non-zero User counts',
      (tester) async {
        await _pumpApp(
          tester,
          authRepository: _authenticatedRepository(_owner('owner-a')),
          dashboardRepository: FakePlatformDashboardRepository(
            onFetch: (_) async => _dashboard(
              institutions: const PlatformInstitutionCounts(
                total: 0,
                active: 0,
                inactive: 0,
              ),
              users: const PlatformUserCounts(total: 1, active: 1),
              recentInstitutions: const [],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('platformDashboardInstitutionEmpty')),
          findsOneWidget,
        );
        expect(
          find.text('No platform institutions exist yet.'),
          findsOneWidget,
        );
        _expectKpi('Total institutions', '0');
        _expectKpi('Active institutions', '0');
        _expectKpi('Inactive institutions', '0');
        _expectKpi('Total users', '1');
        _expectKpi('Active users', '1');
        expect(find.text('No recent institutions'), findsOneWidget);
        expect(find.text('Example School'), findsNothing);
        expect(find.text('Create Institution'), findsNothing);
      },
    );

    testWidgets('shows partial-empty recent section without hiding KPIs', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        authRepository: _authenticatedRepository(_owner('owner-a')),
        dashboardRepository: FakePlatformDashboardRepository(
          onFetch: (_) async => _dashboard(recentInstitutions: const []),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('platformDashboardData')), findsOneWidget);
      expect(
        find.byKey(const Key('platformDashboardInstitutionEmpty')),
        findsNothing,
      );
      _expectKpi('Total institutions', '20');
      _expectKpi('Active users', '2720');
      expect(find.text('No recent institutions'), findsOneWidget);
    });

    testWidgets('safe error hides internals and retry fires once in flight', (
      tester,
    ) async {
      final retryCompleter = Completer<PlatformDashboard>();
      final dashboardRepository = FakePlatformDashboardRepository();
      dashboardRepository.onFetch = (call) {
        if (call == 1) {
          throw _serverFailure(
            'server_error',
            statusCode: 500,
            message: 'SQLSTATE token stack trace https://secret.example',
          );
        }

        return retryCompleter.future;
      };

      await _pumpApp(
        tester,
        authRepository: _authenticatedRepository(_owner('owner-a')),
        dashboardRepository: dashboardRepository,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('platformOwnerShell')), findsOneWidget);
      expect(find.byKey(const Key('platformDashboardError')), findsOneWidget);
      expect(find.text('The dashboard could not be loaded.'), findsOneWidget);
      expect(find.textContaining('SQLSTATE'), findsNothing);
      expect(find.textContaining('secret.example'), findsNothing);
      expect(find.textContaining('stack trace'), findsNothing);

      await tester.tap(find.byKey(const Key('platformDashboardRetryButton')));
      await tester.tap(find.byKey(const Key('platformDashboardRetryButton')));
      await tester.pump();
      expect(dashboardRepository.fetchCalls, 2);
      expect(find.text('Retrying'), findsOneWidget);

      retryCompleter.complete(_dashboard());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('platformDashboardData')), findsOneWidget);
      expect(dashboardRepository.fetchCalls, 2);
    });

    testWidgets('forbidden failure shows safe denial and no dashboard data', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        authRepository: _authenticatedRepository(_owner('owner-a')),
        dashboardRepository: FakePlatformDashboardRepository(
          onFetch: (_) async => throw _serverFailure(
            ApiErrorCodes.forbidden,
            statusCode: 403,
            message: 'Forbidden private backend message.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('platformOwnerShell')), findsOneWidget);
      expect(
        find.text('You do not have permission to view this dashboard.'),
        findsOneWidget,
      );
      expect(find.textContaining('private backend'), findsNothing);
      expect(find.text('Total institutions'), findsNothing);
      expect(find.text('Example School'), findsNothing);
    });

    testWidgets(
      'password-required dashboard failure reconciles to password flow',
      (tester) async {
        var currentUserResponses = 0;
        final authRepository = _authenticatedRepository(_owner('owner-a'));
        authRepository.onCurrentUser = () async {
          currentUserResponses += 1;

          return currentUserResponses == 1
              ? _owner('owner-a')
              : _owner('owner-a', mustChangePassword: true);
        };

        await _pumpApp(
          tester,
          authRepository: authRepository,
          dashboardRepository: FakePlatformDashboardRepository(
            onFetch: (_) async => throw _serverFailure(
              ApiErrorCodes.passwordChangeRequired,
              statusCode: 403,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Password change is required before normal access.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
        expect(find.text('Total institutions'), findsNothing);
      },
    );

    testWidgets('logout while loading removes dashboard data immediately', (
      tester,
    ) async {
      final dashboardCompleter = Completer<PlatformDashboard>();
      final dashboardRepository = FakePlatformDashboardRepository(
        onFetch: (_) => dashboardCompleter.future,
      );

      await _pumpApp(
        tester,
        authRepository: _authenticatedRepository(_owner('owner-a')),
        dashboardRepository: dashboardRepository,
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('entryLogoutButton')));
      await tester.pumpAndSettle();
      dashboardCompleter.complete(_dashboard(label: 'Old Owner'));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.byKey(const Key('platformOwnerShell')), findsNothing);
      expect(find.text('Old Owner School'), findsNothing);
    });

    testWidgets('account switch shows only the new owner dashboard data', (
      tester,
    ) async {
      final authRepository = _authenticatedRepository(
        _owner('owner-a', fullName: 'Owner A'),
      );
      final dashboardRepository = FakePlatformDashboardRepository(
        onFetch: (call) async => call == 1
            ? _dashboard(label: 'Owner A')
            : _dashboard(label: 'Owner B'),
      );

      await _pumpApp(
        tester,
        authRepository: authRepository,
        dashboardRepository: dashboardRepository,
      );
      await tester.pumpAndSettle();
      expect(find.text('Owner A School'), findsOneWidget);

      await tester.tap(find.byKey(const Key('entryLogoutButton')));
      await tester.pumpAndSettle();
      authRepository.onSignIn = (_, _) async =>
          _owner('owner-b', fullName: 'Owner B');
      await _submitLogin(tester, login: 'owner-b');

      expect(find.text('Current user: Owner B'), findsOneWidget);
      expect(find.text('Owner B School'), findsOneWidget);
      expect(find.text('Owner A School'), findsNothing);
      expect(find.textContaining('Owner A'), findsNothing);
    });

    testWidgets('dashboard has no overflow at compact and wide desktop sizes', (
      tester,
    ) async {
      for (final size in [const Size(800, 600), const Size(1440, 900)]) {
        await tester.binding.setSurfaceSize(size);
        await _pumpApp(
          tester,
          authRepository: _authenticatedRepository(_owner('owner-a')),
          dashboardRepository: FakePlatformDashboardRepository(
            onFetch: (_) async => _dashboard(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('platformDashboardData')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    });

    testWidgets('/platform-owner/institutions remains separate placeholder', (
      tester,
    ) async {
      final dashboardRepository = FakePlatformDashboardRepository(
        onFetch: (_) async => _dashboard(),
      );

      await _pumpApp(
        tester,
        initialLocation: AppRoutePaths.platformOwnerInstitutions,
        authRepository: _authenticatedRepository(_owner('owner-a')),
        dashboardRepository: dashboardRepository,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('platformOwnerInstitutionsPlaceholder')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('platformDashboardData')), findsNothing);
      expect(find.text('Total institutions'), findsNothing);
      expect(dashboardRepository.fetchCalls, 0);
    });
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  String initialLocation = AppRoutePaths.platformOwner,
  required FakeAuthRepository authRepository,
  required FakePlatformDashboardRepository dashboardRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appInitialLocationProvider.overrideWithValue(initialLocation),
        authRepositoryProvider.overrideWithValue(authRepository),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        platformDashboardRepositoryProvider.overrideWithValue(
          dashboardRepository,
        ),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _submitLogin(WidgetTester tester, {required String login}) async {
  await tester.enterText(find.byKey(const Key('loginField')), login);
  await tester.enterText(find.byKey(const Key('passwordField')), 'secret');
  await tester.tap(find.byKey(const Key('signInButton')));
  await tester.pumpAndSettle();
}

void _expectKpi(String label, String value) {
  expect(find.byKey(Key('platformDashboardKpi${label}Label')), findsOneWidget);
  expect(find.byKey(Key('platformDashboardKpi${label}Value')), findsOneWidget);
  expect(
    find.descendant(
      of: find.byKey(Key('platformDashboardKpi$label')),
      matching: find.text(value),
    ),
    findsOneWidget,
  );
}

void _expectNoLaterScopeText() {
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
  expect(find.text('Chart'), findsNothing);
  expect(find.text('Trend'), findsNothing);
  expect(find.text('Export'), findsNothing);
}

PlatformDashboard _dashboard({
  String label = 'Example',
  PlatformInstitutionCounts institutions = const PlatformInstitutionCounts(
    total: 20,
    active: 18,
    inactive: 2,
  ),
  PlatformUserCounts users = const PlatformUserCounts(
    total: 2800,
    active: 2720,
  ),
  List<RecentPlatformInstitution>? recentInstitutions,
}) {
  return PlatformDashboard(
    institutions: institutions,
    users: users,
    recentInstitutions:
        recentInstitutions ?? [_recentInstitution(name: '$label School')],
  );
}

RecentPlatformInstitution _recentInstitution({
  String id = '00000000-0000-0000-0000-000000000001',
  required String name,
  PlatformInstitutionType type = PlatformInstitutionType.school,
  PlatformInstitutionStatus status = PlatformInstitutionStatus.active,
  DateTime? createdAt,
}) {
  return RecentPlatformInstitution(
    id: id,
    name: name,
    type: type,
    status: status,
    createdAt: createdAt ?? DateTime.utc(2026, 8, 1, 10),
  );
}

AuthUser _owner(
  String loginName, {
  String? fullName,
  bool mustChangePassword = false,
}) {
  return _user(
    loginName: loginName,
    role: UserRole.platformOwner,
    fullName: fullName ?? '$loginName User',
    mustChangePassword: mustChangePassword,
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

ApiRequestException _serverFailure(
  String code, {
  required int statusCode,
  String message = 'Server rejected the dashboard request.',
}) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: statusCode,
      error: ApiErrorResponse(
        message: message,
        code: code,
        fieldErrors: const {},
        requestId: 'req-1',
      ),
    ),
  );
}

class FakePlatformDashboardRepository implements PlatformDashboardRepository {
  FakePlatformDashboardRepository({this.onFetch});

  Future<PlatformDashboard> Function(int call)? onFetch;
  var fetchCalls = 0;

  @override
  Future<PlatformDashboard> fetchDashboard() {
    fetchCalls += 1;

    return onFetch?.call(fetchCalls) ?? Future.value(_dashboard());
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.storedToken, this.onCurrentUser});

  String? storedToken;
  Future<AuthUser> Function()? onCurrentUser;
  Future<AuthUser> Function(String login, String password)? onSignIn;
  var currentUserCalls = 0;
  var signOutCalls = 0;

  @override
  Future<AuthUser> currentUser() {
    currentUserCalls += 1;

    return onCurrentUser?.call() ?? Future.value(_owner('owner-a'));
  }

  @override
  Future<AuthUser> signIn({required String login, required String password}) {
    storedToken = 'token-$login';

    return onSignIn?.call(login, password) ?? Future.value(_owner(login));
  }

  @override
  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    return _owner('owner-a');
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    storedToken = null;
  }

  @override
  Future<String?> readStoredToken() async {
    return storedToken;
  }

  @override
  Future<void> clearToken() async {
    storedToken = null;
  }

  @override
  Future<bool> clearTokenIfVersion(int tokenVersion) async {
    storedToken = null;

    return true;
  }
}

FakeAuthRepository _authenticatedRepository(AuthUser user) {
  return FakeAuthRepository(
    storedToken: 'token-a',
    onCurrentUser: () async => user,
  );
}
