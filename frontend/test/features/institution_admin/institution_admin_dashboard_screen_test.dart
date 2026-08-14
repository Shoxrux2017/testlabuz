import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/app.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_router.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_dashboard.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_dashboard_repository.dart';

void main() {
  group('InstitutionAdminDashboardScreen', () {
    testWidgets('keeps the shell and exposes an honest loading live region', (
      tester,
    ) async {
      final request = Completer<InstitutionDashboard>();
      final repository = FakeInstitutionDashboardRepository(
        onFetch: (_) => request.future,
      );
      final semantics = tester.ensureSemantics();

      await _pumpApp(tester, dashboardRepository: repository);
      await tester.pump();

      expect(find.byKey(const Key('institutionAdminShell')), findsOneWidget);
      expect(
        find.byKey(const Key('institutionDashboardLoading')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Loading institution dashboard'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('institutionDashboardData')), findsNothing);
      expect(find.text('Teachers'), findsNothing);
      expect(find.text('Dashboard unavailable'), findsNothing);
      expect(repository.fetchCalls, 1);
      semantics.dispose();
    });

    testWidgets('renders exactly three ordered authoritative total cards', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        dashboardRepository: FakeInstitutionDashboardRepository(
          onFetch: (_) async => const InstitutionDashboard(
            teachers: 30,
            students: 600,
            parents: 450,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('institutionDashboardData')), findsOneWidget);
      expect(find.text('Institution Dashboard'), findsOneWidget);
      expect(find.text('Total accounts'), findsNWidgets(3));
      _expectCard(
        cardKey: 'institutionDashboardTeachersCard',
        valueKey: 'institutionDashboardTeachersValue',
        title: 'Teachers',
        value: '30',
      );
      _expectCard(
        cardKey: 'institutionDashboardStudentsCard',
        valueKey: 'institutionDashboardStudentsValue',
        title: 'Students',
        value: '600',
      );
      _expectCard(
        cardKey: 'institutionDashboardParentsCard',
        valueKey: 'institutionDashboardParentsValue',
        title: 'Parents',
        value: '450',
      );
      final cards = find.byType(Card).evaluate().toList();
      expect(cards, hasLength(3));
      expect(
        cards[0].widget.key,
        const Key('institutionDashboardTeachersCard'),
      );
      expect(
        cards[1].widget.key,
        const Key('institutionDashboardStudentsCard'),
      );
      expect(cards[2].widget.key, const Key('institutionDashboardParentsCard'));
      expect(find.text('No users yet.'), findsNothing);
      expect(find.text('Active'), findsNothing);
      expect(find.text('Inactive'), findsNothing);
      expect(find.text('Groups'), findsNothing);
      expect(find.text('Topics'), findsNothing);
      expect(find.text('Recent users'), findsNothing);
      expect(find.text('Create User'), findsNothing);
    });

    testWidgets('distinguishes partial zero from successful all-zero data', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        dashboardRepository: FakeInstitutionDashboardRepository(
          onFetch: (_) async =>
              const InstitutionDashboard(teachers: 0, students: 5, parents: 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('institutionDashboardEmpty')), findsNothing);
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('5'), findsOneWidget);

      await _pumpApp(
        tester,
        dashboardRepository: FakeInstitutionDashboardRepository(
          onFetch: (_) async =>
              const InstitutionDashboard(teachers: 0, students: 0, parents: 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('institutionDashboardData')), findsOneWidget);
      expect(
        find.byKey(const Key('institutionDashboardEmpty')),
        findsOneWidget,
      );
      expect(find.text('No users yet.'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(3));
    });

    testWidgets('Refresh shows no stale counts and performs one request', (
      tester,
    ) async {
      final refresh = Completer<InstitutionDashboard>();
      final repository = FakeInstitutionDashboardRepository(
        onFetch: (call) async {
          if (call == 1) {
            return const InstitutionDashboard(
              teachers: 1,
              students: 2,
              parents: 3,
            );
          }

          return refresh.future;
        },
      );
      await _pumpApp(tester, dashboardRepository: repository);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('institutionDashboardRefreshButton')),
      );
      await tester.pump();

      expect(repository.fetchCalls, 2);
      expect(
        find.byKey(const Key('institutionDashboardLoading')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('institutionDashboardData')), findsNothing);
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsNothing);
      expect(
        find.byKey(const Key('institutionDashboardRefreshButton')),
        findsNothing,
      );

      refresh.complete(
        const InstitutionDashboard(teachers: 10, students: 20, parents: 30),
      );
      await tester.pumpAndSettle();
      expect(find.text('10'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('safe errors never render raw backend details', (tester) async {
      final cases = <(ApiFailure, String)>[
        (_serverFailure('authentication_required'), 'Please sign in again.'),
        (
          _serverFailure('password_change_required'),
          'Password change is required before dashboard access.',
        ),
        (_serverFailure('user_inactive'), 'This account is inactive.'),
        (
          _serverFailure('institution_inactive'),
          'This institution is inactive.',
        ),
        (
          _serverFailure('forbidden'),
          'You do not have permission to view this dashboard.',
        ),
        (
          _serverFailure('validation_failed'),
          'The dashboard request did not match the API contract.',
        ),
        (
          _localFailure(ApiFailureKind.connection),
          'Could not reach the server. Check the connection and try again.',
        ),
        (
          _localFailure(ApiFailureKind.timeout),
          'The dashboard request timed out.',
        ),
        (
          _localFailure(ApiFailureKind.invalidResponse),
          'The server returned an unexpected dashboard response.',
        ),
        (
          _localFailure(ApiFailureKind.cancelled),
          'The dashboard request was cancelled.',
        ),
        (_serverFailure('server_error'), 'The dashboard could not be loaded.'),
      ];

      for (final (failure, message) in cases) {
        await _pumpApp(
          tester,
          dashboardRepository: FakeInstitutionDashboardRepository(
            onFetch: (_) async => throw ApiRequestException(failure),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('institutionDashboardError')),
          findsOneWidget,
        );
        expect(find.text('Dashboard unavailable'), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(find.textContaining('SQLSTATE'), findsNothing);
        expect(find.textContaining('private-token'), findsNothing);
        expect(find.textContaining('req-private'), findsNothing);
        expect(find.byKey(const Key('institutionDashboardData')), findsNothing);
      }
    });

    testWidgets('Retry is disabled while in flight and deduplicates intent', (
      tester,
    ) async {
      final retry = Completer<InstitutionDashboard>();
      final repository = FakeInstitutionDashboardRepository(
        onFetch: (call) async {
          if (call == 1) {
            throw ApiRequestException(_localFailure(ApiFailureKind.connection));
          }

          return retry.future;
        },
      );
      await _pumpApp(tester, dashboardRepository: repository);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('institutionDashboardRetryButton')),
      );
      await tester.tap(
        find.byKey(const Key('institutionDashboardRetryButton')),
      );
      await tester.pump();
      expect(repository.fetchCalls, 2);
      expect(find.text('Retrying'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('institutionDashboardRetryButton')),
      );
      expect(button.onPressed, isNull);

      retry.complete(
        const InstitutionDashboard(teachers: 4, students: 5, parents: 6),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('institutionDashboardData')), findsOneWidget);
      expect(repository.fetchCalls, 2);
    });

    testWidgets('responsive shell and dashboard remain overflow-free', (
      tester,
    ) async {
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      });

      for (final size in const [Size(800, 600), Size(1440, 900)]) {
        for (final textScale in const [1.0, 2.0]) {
          await tester.binding.setSurfaceSize(size);
          tester.binding.platformDispatcher.textScaleFactorTestValue =
              textScale;
          await _pumpApp(
            tester,
            dashboardRepository: FakeInstitutionDashboardRepository(
              onFetch: (_) async => const InstitutionDashboard(
                teachers: 300000,
                students: 600000,
                parents: 450000,
              ),
            ),
            user: _admin(
              fullName: List.filled(10, 'LongAdmin').join(),
              institutionName: List.filled(10, 'LongInstitution').join(),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('institutionAdminShell')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('institutionDashboardData')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('Tab then Enter activates the accessible Refresh action', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final refresh = Completer<InstitutionDashboard>();
      final repository = FakeInstitutionDashboardRepository(
        onFetch: (call) async => call == 1
            ? const InstitutionDashboard(teachers: 1, students: 2, parents: 3)
            : refresh.future,
      );
      await _pumpApp(tester, dashboardRepository: repository);
      await tester.pumpAndSettle();

      for (var index = 0; index < 6; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab, platform: 'windows');
        await tester.pump();
      }
      final refreshFinder = find.byKey(
        const Key('institutionDashboardRefreshButton'),
      );
      expect(Focus.of(tester.element(refreshFinder)).hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter, platform: 'windows');
      await tester.pump();
      expect(repository.fetchCalls, 2);
      expect(
        find.byKey(const Key('institutionDashboardLoading')),
        findsOneWidget,
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('non-dashboard routes request nothing and re-entry is fresh', (
      tester,
    ) async {
      final nonDashboardRoutes = [
        AppRoutePaths.institutionAdminUsers,
        AppRoutePaths.institutionAdminUserCreate,
        AppRoutePaths.institutionAdminUserDetailLocation(
          '550e8400-e29b-41d4-a716-446655440000',
        ),
        AppRoutePaths.institutionAdminInstitution,
        AppRoutePaths.institutionAdminSettings,
      ];

      for (final route in nonDashboardRoutes) {
        final repository = FakeInstitutionDashboardRepository();
        await _pumpApp(
          tester,
          initialLocation: route,
          dashboardRepository: repository,
        );
        await tester.pumpAndSettle();
        expect(repository.fetchCalls, 0, reason: route);
      }

      final repository = FakeInstitutionDashboardRepository();
      await _pumpApp(tester, dashboardRepository: repository);
      await tester.pumpAndSettle();
      expect(repository.fetchCalls, 1);

      await _tapDestination(tester, 'Users');
      await tester.pumpAndSettle();
      expect(repository.fetchCalls, 1);
      expect(find.byKey(const Key('institutionDashboardData')), findsNothing);

      await _tapDestination(tester, 'Dashboard');
      await tester.pumpAndSettle();
      expect(repository.fetchCalls, 2);
      expect(find.byKey(const Key('institutionDashboardData')), findsOneWidget);

      GoRouter.of(
        tester.element(find.byKey(const Key('institutionAdminShell'))),
      ).pop();
      await tester.pumpAndSettle();
      expect(
        GoRouter.of(
          tester.element(find.byType(Scaffold).first),
        ).routeInformationProvider.value.uri.path,
        AppRoutePaths.institutionAdminUsers,
      );
    });

    testWidgets(
      'logout during load and account switch cannot reveal old totals',
      (tester) async {
        final oldRequest = Completer<InstitutionDashboard>();
        final authRepository = _authenticatedRepository(_admin());
        final repository = FakeInstitutionDashboardRepository(
          onFetch: (call) async => call == 1
              ? oldRequest.future
              : const InstitutionDashboard(
                  teachers: 2,
                  students: 20,
                  parents: 12,
                ),
        );
        await _pumpApp(
          tester,
          authRepository: authRepository,
          dashboardRepository: repository,
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('entryLogoutButton')));
        await tester.pumpAndSettle();
        expect(find.text('Login'), findsOneWidget);

        authRepository.onSignIn = (_, _) async => _admin(
          id: 'admin-b',
          institutionId: 'institution-b',
          institutionName: 'Institution B',
        );
        await _submitLogin(tester, login: 'admin-b');
        expect(find.text('2'), findsOneWidget);
        expect(find.text('20'), findsOneWidget);

        oldRequest.complete(
          const InstitutionDashboard(teachers: 99, students: 99, parents: 99),
        );
        await tester.pumpAndSettle();
        expect(find.text('99'), findsNothing);
        expect(find.text('Institution: Institution B'), findsOneWidget);
      },
    );
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  String initialLocation = AppRoutePaths.institutionAdmin,
  FakeAuthRepository? authRepository,
  AuthUser? user,
  required FakeInstitutionDashboardRepository dashboardRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appInitialLocationProvider.overrideWithValue(initialLocation),
        authRepositoryProvider.overrideWithValue(
          authRepository ?? _authenticatedRepository(user ?? _admin()),
        ),
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        institutionDashboardRepositoryProvider.overrideWithValue(
          dashboardRepository,
        ),
      ],
      child: const TestLabUzApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _tapDestination(WidgetTester tester, String label) async {
  final navigation = find.byKey(const Key('institutionAdminNavigation'));
  await tester.tap(find.descendant(of: navigation, matching: find.text(label)));
}

Future<void> _submitLogin(WidgetTester tester, {required String login}) async {
  await tester.enterText(find.byKey(const Key('loginField')), login);
  await tester.enterText(find.byKey(const Key('passwordField')), 'secret');
  await tester.tap(find.byKey(const Key('signInButton')));
  await tester.pumpAndSettle();
}

void _expectCard({
  required String cardKey,
  required String valueKey,
  required String title,
  required String value,
}) {
  final card = find.byKey(Key(cardKey));
  expect(card, findsOneWidget);
  expect(find.descendant(of: card, matching: find.text(title)), findsOneWidget);
  expect(find.byKey(Key(valueKey)), findsOneWidget);
  expect(find.descendant(of: card, matching: find.text(value)), findsOneWidget);
  expect(
    find.descendant(of: card, matching: find.text('Total accounts')),
    findsOneWidget,
  );
}

AuthUser _admin({
  String id = 'admin-a',
  String institutionId = 'institution-a',
  String fullName = 'Admin User',
  String institutionName = 'Institution A',
}) {
  return AuthUser(
    id: id,
    institutionId: institutionId,
    role: UserRole.institutionAdmin,
    fullName: fullName,
    loginName: id,
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: false,
    institution: AuthInstitution(
      id: institutionId,
      name: institutionName,
      status: 'active',
      timezone: 'Asia/Tashkent',
    ),
  );
}

ApiFailure _serverFailure(String code) {
  return ApiFailure.fromServerError(
    statusCode: code == 'authentication_required' ? 401 : 403,
    error: ApiErrorResponse(
      message: 'SQLSTATE private-token backend detail.',
      code: code,
      fieldErrors: const {},
      requestId: 'req-private',
    ),
  );
}

ApiFailure _localFailure(ApiFailureKind kind) {
  return ApiFailure.local(
    kind: kind,
    message: 'SQLSTATE private-token local detail.',
  );
}

class FakeInstitutionDashboardRepository
    implements InstitutionDashboardRepository {
  FakeInstitutionDashboardRepository({this.onFetch});

  Future<InstitutionDashboard> Function(int call)? onFetch;
  var fetchCalls = 0;

  @override
  Future<InstitutionDashboard> fetchDashboard() {
    fetchCalls += 1;

    return onFetch?.call(fetchCalls) ??
        Future.value(
          const InstitutionDashboard(teachers: 1, students: 2, parents: 3),
        );
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.storedToken, this.onCurrentUser});

  String? storedToken;
  Future<AuthUser> Function()? onCurrentUser;
  Future<AuthUser> Function(String login, String password)? onSignIn;
  var currentUserCalls = 0;

  @override
  Future<AuthUser> currentUser() {
    currentUserCalls += 1;

    return onCurrentUser?.call() ?? Future.value(_admin());
  }

  @override
  Future<AuthUser> signIn({required String login, required String password}) {
    storedToken = 'token-$login';

    return onSignIn?.call(login, password) ?? Future.value(_admin(id: login));
  }

  @override
  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async => _admin();

  @override
  Future<void> signOut() async {
    storedToken = null;
  }

  @override
  Future<String?> readStoredToken() async => storedToken;

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
