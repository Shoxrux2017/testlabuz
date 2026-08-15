import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/app/router/app_route_paths.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_detail_repository.dart';
import 'package:testlabuz_client/features/institution_admin/presentation/institution_admin_user_detail_screen.dart';

void main() {
  testWidgets('renders all four read-only sections and twelve active fields', (
    tester,
  ) async {
    await _pumpScreen(tester, _FakeDetailRepository());

    for (final text in const [
      'User details',
      'Identity',
      'Contact',
      'Account state',
      'Activity and lifecycle',
      'Full name',
      'Login name',
      'Role',
      'User ID',
      'Email',
      'Phone',
      'Status',
      'First login',
      'Last login',
      'Deactivated',
      'Created',
      'Updated',
      'Teacher Name',
      'teacher01',
      'Teacher',
      'Active',
      'Completed',
      'Never',
      'Not deactivated',
      'Not provided',
      '2026-08-07 15:00 UTC',
      '2026-08-07 16:00 UTC',
      'Back to Users',
      'Refresh',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text(_userId), findsOneWidget);
    final userIdField = find.byKey(
      const Key('institutionUserDetailValueUser ID'),
    );
    expect(userIdField, findsOneWidget);
    expect(tester.widget(userIdField), isA<SelectableText>());
    _expectNoMutationControls();
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders inactive, first-login, contact, and lifecycle values', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      _FakeDetailRepository(
        user: _user(
          role: InstitutionUserRole.parent,
          email: 'parent@example.uz',
          phone: '+998901234567',
          isActive: false,
          mustChangePassword: true,
          lastLoginAt: DateTime.utc(2026, 8, 6, 13, 5),
          deactivatedAt: DateTime.utc(2026, 8, 8, 9, 30),
        ),
      ),
    );

    for (final text in const [
      'Parent',
      'parent@example.uz',
      '+998901234567',
      'Inactive',
      'Password change required',
      '2026-08-06 13:05 UTC',
      '2026-08-08 09:30 UTC',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    _expectNoMutationControls();
  });

  testWidgets('scope-safe not found reveals no target and has no Retry', (
    tester,
  ) async {
    final repository = _FakeDetailRepository(
      onFetch: (_, _) => Future.error(
        ApiRequestException(
          _serverFailure(statusCode: 404, code: ApiErrorCodes.resourceNotFound),
        ),
      ),
    );
    await _pumpScreen(tester, repository);

    expect(find.text('User unavailable'), findsOneWidget);
    expect(
      find.text(
        'This user does not exist or is not available to your account.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Refresh'), findsNothing);
    expect(find.text(_userId), findsNothing);
    expect(find.text('Private server message.'), findsNothing);
    _expectNoMutationControls();
  });

  testWidgets('defensive invalid target is unavailable without a request', (
    tester,
  ) async {
    final repository = _FakeDetailRepository();
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _providerScope(
        repository,
        child: const MaterialApp(
          home: InstitutionAdminUserDetailScreen(userId: 'not-a-uuid'),
        ),
      ),
    );
    await _pumpAsyncWork(tester);

    expect(repository.fetchCalls, 0);
    expect(find.text('User unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('not-a-uuid'), findsNothing);
  });

  testWidgets('retryable error uses safe copy and duplicate-protected Retry', (
    tester,
  ) async {
    final retry = Completer<InstitutionUser>();
    final repository = _FakeDetailRepository(
      onFetch: (target, call) {
        if (call == 1) {
          return Future.error(
            ApiRequestException(
              ApiFailure.local(
                kind: ApiFailureKind.connection,
                message: 'Private connection and target $_userId.',
              ),
            ),
          );
        }
        return retry.future;
      },
    );
    await _pumpScreen(tester, repository);

    expect(find.text('Unable to load user details'), findsOneWidget);
    expect(
      find.text('User details could not be loaded safely.'),
      findsOneWidget,
    );
    expect(find.text('Private connection and target $_userId.'), findsNothing);
    expect(find.text(_userId), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Retry'), findsNothing);
    expect(repository.fetchCalls, 2);

    retry.complete(_user());
    await _pumpAsyncWork(tester);
    expect(find.text('Teacher Name'), findsWidgets);
    expect(repository.fetchCalls, 2);
  });

  testWidgets('non-retryable error never exposes Retry or raw failure', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      _FakeDetailRepository(
        onFetch: (_, _) => Future.error(
          ApiRequestException(
            _serverFailure(statusCode: 403, code: ApiErrorCodes.forbidden),
          ),
        ),
      ),
    );

    expect(find.text('Unable to load user details'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Private server message.'), findsNothing);
    expect(find.text(_userId), findsNothing);
  });

  testWidgets('refresh announces only its busy state as a live region', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final refresh = Completer<InstitutionUser>();
    final repository = _FakeDetailRepository(
      onFetch: (target, call) =>
          call == 1 ? Future.value(_user(id: target)) : refresh.future,
    );
    await _pumpScreen(tester, repository);

    final containerNode = tester.getSemantics(
      find.byKey(const Key('institutionUserDetailSemanticsContainer')),
    );
    expect(containerNode.flagsCollection.isLiveRegion, isFalse);

    await tester.tap(find.byKey(const Key('institutionUserDetailRefresh')));
    await tester.pump();

    final announcement = tester.getSemantics(
      find.byKey(const Key('institutionUserDetailRefreshAnnouncement')),
    );
    expect(announcement.flagsCollection.isLiveRegion, isTrue);
    expect(announcement.label, 'Refreshing user details');
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('institutionUserDetailRefresh')),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Teacher Name'), findsWidgets);

    refresh.complete(_user(fullName: 'Refreshed User'));
    await _pumpAsyncWork(tester);
    expect(find.text('Refreshed User'), findsWidgets);
    expect(repository.fetchCalls, 2);
    semantics.dispose();
  });

  testWidgets('compact, wide, text-scale 2, and long values never overflow', (
    tester,
  ) async {
    final longValue = List.filled(18, 'LongInstitutionUserValue').join('-');
    final cases = const [
      (size: Size(800, 600), scale: 1.0),
      (size: Size(1440, 900), scale: 1.0),
      (size: Size(800, 600), scale: 2.0),
    ];

    for (final testCase in cases) {
      await tester.binding.setSurfaceSize(testCase.size);
      tester.platformDispatcher.textScaleFactorTestValue = testCase.scale;
      await _pumpScreen(
        tester,
        _FakeDetailRepository(
          user: _user(
            fullName: longValue,
            loginName: longValue,
            email: '$longValue@example.uz',
            phone: longValue,
          ),
        ),
        setDefaultSurface: false,
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$testCase');
    }
  });

  testWidgets('Tab order starts with Back then Refresh and Enter refreshes', (
    tester,
  ) async {
    final repository = _FakeDetailRepository();
    await _pumpScreen(tester, repository);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab, platform: 'windows');
    await tester.pump();
    expect(
      Focus.of(tester.element(find.text('Back to Users').first)).hasFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab, platform: 'windows');
    await tester.pump();
    expect(Focus.of(tester.element(find.text('Refresh'))).hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter, platform: 'windows');
    await _pumpAsyncWork(tester);
    expect(repository.fetchCalls, 2);
  });

  testWidgets('rapid target A to B never publishes stale A data', (
    tester,
  ) async {
    const targetA = '00000000-0000-0000-0000-00000000000a';
    const targetB = '00000000-0000-0000-0000-00000000000b';
    final requestA = Completer<InstitutionUser>();
    final requestB = Completer<InstitutionUser>();
    final repository = _FakeDetailRepository(
      onFetch: (target, _) =>
          target == targetA ? requestA.future : requestB.future,
    );
    final container = ProviderContainer(
      overrides: [
        appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
        authSessionControllerProvider.overrideWith(
          () => _FakeAuthSessionController(_admin()),
        ),
        institutionUserDetailRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: InstitutionAdminUserDetailScreen(userId: targetA),
        ),
      ),
    );
    await _pumpAsyncWork(tester);
    expect(repository.targets, [targetA]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: InstitutionAdminUserDetailScreen(userId: targetB),
        ),
      ),
    );
    await _pumpAsyncWork(tester);
    expect(repository.targets, [targetA, targetB]);

    requestA.complete(_user(id: targetA, fullName: 'Stale User A'));
    await _pumpAsyncWork(tester);
    expect(find.text('Stale User A'), findsNothing);
    expect(find.text(targetA), findsNothing);

    requestB.complete(_user(id: targetB, fullName: 'Current User B'));
    await _pumpAsyncWork(tester);
    expect(find.text('Current User B'), findsWidgets);
    expect(find.text(targetB), findsOneWidget);
  });

  testWidgets('Back to Users always navigates to the canonical list route', (
    tester,
  ) async {
    final repository = _FakeDetailRepository();
    final router = GoRouter(
      initialLocation: AppRoutePaths.institutionAdminUserDetailLocation(
        _userId,
      ),
      routes: [
        GoRoute(
          path: AppRoutePaths.institutionAdminUsers,
          builder: (_, _) =>
              const Scaffold(body: Text('Canonical Users destination')),
        ),
        GoRoute(
          path: AppRoutePaths.institutionAdminUserDetail,
          builder: (_, state) => InstitutionAdminUserDetailScreen(
            userId:
                state.pathParameters[AppRoutePaths
                    .institutionAdminUserIdParameter] ??
                '',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _providerScope(
        repository,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _pumpAsyncWork(tester);
    await tester.tap(find.text('Back to Users'));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutePaths.institutionAdminUsers,
    );
    expect(find.text('Canonical Users destination'), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeDetailRepository repository, {
  bool setDefaultSurface = true,
}) async {
  if (setDefaultSurface) {
    await tester.binding.setSurfaceSize(const Size(800, 600));
  }
  addTearDown(() {
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    _providerScope(
      repository,
      child: const MaterialApp(
        home: InstitutionAdminUserDetailScreen(userId: _userId),
      ),
    ),
  );
  await _pumpAsyncWork(tester);
}

Widget _providerScope(
  _FakeDetailRepository repository, {
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      appDeviceSurfaceProvider.overrideWithValue(AppDeviceSurface.desktop),
      authSessionControllerProvider.overrideWith(
        () => _FakeAuthSessionController(_admin()),
      ),
      institutionUserDetailRepositoryProvider.overrideWithValue(repository),
    ],
    child: child,
  );
}

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void _expectNoMutationControls() {
  for (final label in const [
    'Edit',
    'Create',
    'Activate',
    'Deactivate',
    'Delete',
    'Reset password',
  ]) {
    expect(find.text(label), findsNothing, reason: label);
  }
}

const _userId = '00000000-0000-0000-0000-000000000001';

AuthSessionState _admin() => AuthSessionState.authenticated(
  const AuthUser(
    id: 'admin-a',
    institutionId: 'institution-a',
    role: UserRole.institutionAdmin,
    fullName: 'Admin User',
    loginName: 'admin',
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: false,
    institution: AuthInstitution(
      id: 'institution-a',
      name: 'Institution A',
      status: 'active',
      timezone: 'Asia/Tashkent',
    ),
  ),
);

InstitutionUser _user({
  String id = _userId,
  InstitutionUserRole role = InstitutionUserRole.teacher,
  String fullName = 'Teacher Name',
  String loginName = 'teacher01',
  String? email,
  String? phone,
  bool isActive = true,
  bool mustChangePassword = false,
  DateTime? lastLoginAt,
  DateTime? deactivatedAt,
}) => InstitutionUser(
  id: id,
  role: role,
  fullName: fullName,
  loginName: loginName,
  email: email,
  phone: phone,
  isActive: isActive,
  mustChangePassword: mustChangePassword,
  lastLoginAt: lastLoginAt,
  deactivatedAt: deactivatedAt,
  createdAt: DateTime.utc(2026, 8, 7, 15),
  updatedAt: DateTime.utc(2026, 8, 7, 16),
);

ApiFailure _serverFailure({required int statusCode, required String code}) {
  return ApiFailure(
    kind: ApiFailureKind.server,
    statusCode: statusCode,
    serverCode: code,
    message: 'Private server message.',
  );
}

class _FakeDetailRepository implements InstitutionUserDetailRepository {
  _FakeDetailRepository({InstitutionUser? user, this.onFetch})
    : user = user ?? _user();

  final InstitutionUser user;
  final Future<InstitutionUser> Function(String target, int call)? onFetch;
  final targets = <String>[];
  var fetchCalls = 0;

  @override
  Future<InstitutionUser> fetchUser(String userId) {
    fetchCalls += 1;
    targets.add(userId);
    return onFetch?.call(userId, fetchCalls) ?? Future.value(user);
  }
}

class _FakeAuthSessionController extends AuthSessionController {
  _FakeAuthSessionController(this.session);

  final AuthSessionState session;

  @override
  AuthSessionState build() => session;
}
