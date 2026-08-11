import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_dashboard_controller.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_dashboard_state.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_dashboard_repository.dart';

void main() {
  group('PlatformDashboardController', () {
    test('eligible entry loads once and resolves to data', () async {
      final dashboardCompleter = Completer<PlatformDashboard>();
      final dashboardRepository = FakePlatformDashboardRepository(
        onFetch: () => dashboardCompleter.future,
      );
      final container = _container(
        authController: FakeAuthSessionController.authenticated(
          _owner('owner-a'),
        ),
        dashboardRepository: dashboardRepository,
      );
      final subscription = _listen(container);

      await _flush();

      expect(subscription.read().status, PlatformDashboardStatus.loading);
      expect(dashboardRepository.fetchCalls, 1);

      container.read(platformDashboardControllerProvider);
      container.read(platformDashboardControllerProvider);
      expect(dashboardRepository.fetchCalls, 1);

      dashboardCompleter.complete(_dashboard(label: 'A'));
      await _flush();

      final state = subscription.read();
      expect(state.status, PlatformDashboardStatus.data);
      expect(state.dashboard?.recentInstitutions.single.name, 'A School');
      expect(dashboardRepository.fetchCalls, 1);
    });

    test('classifies Institution-empty independently of User counts', () async {
      final dashboardRepository = FakePlatformDashboardRepository(
        onFetch: () async => _dashboard(
          institutions: const PlatformInstitutionCounts(
            total: 0,
            active: 0,
            inactive: 0,
          ),
          users: const PlatformUserCounts(total: 1, active: 1),
          recentInstitutions: const [],
        ),
      );
      final container = _container(
        authController: FakeAuthSessionController.authenticated(
          _owner('owner-a'),
        ),
        dashboardRepository: dashboardRepository,
      );
      final subscription = _listen(container);

      await _flush();

      final state = subscription.read();
      expect(state.status, PlatformDashboardStatus.data);
      expect(state.isInstitutionEmpty, isTrue);
      expect(state.dashboard?.users.total, 1);
      expect(state.dashboard?.users.active, 1);
    });

    test('keeps KPI data when only recent Institutions are empty', () async {
      final dashboardRepository = FakePlatformDashboardRepository(
        onFetch: () async => _dashboard(recentInstitutions: const []),
      );
      final container = _container(
        authController: FakeAuthSessionController.authenticated(
          _owner('owner-a'),
        ),
        dashboardRepository: dashboardRepository,
      );
      final subscription = _listen(container);

      await _flush();

      final state = subscription.read();
      expect(state.status, PlatformDashboardStatus.data);
      expect(state.isInstitutionEmpty, isFalse);
      expect(state.dashboard?.institutions.total, 20);
      expect(state.dashboard?.recentInstitutions, isEmpty);
    });

    test('failure stops loading and retry is in-flight protected', () async {
      final retryCompleter = Completer<PlatformDashboard>();
      final dashboardRepository = FakePlatformDashboardRepository();
      dashboardRepository.onFetch = () async {
        if (dashboardRepository.fetchCalls == 1) {
          throw _localFailure(ApiFailureKind.connection);
        }

        return retryCompleter.future;
      };
      final container = _container(
        authController: FakeAuthSessionController.authenticated(
          _owner('owner-a'),
        ),
        dashboardRepository: dashboardRepository,
      );
      final subscription = _listen(container);

      await _flush();

      expect(subscription.read().status, PlatformDashboardStatus.error);
      expect(subscription.read().failure?.kind, ApiFailureKind.connection);
      expect(dashboardRepository.fetchCalls, 1);

      final retryA = container
          .read(platformDashboardControllerProvider.notifier)
          .retry();
      final retryB = container
          .read(platformDashboardControllerProvider.notifier)
          .retry();
      expect(subscription.read().isRetryInFlight, isTrue);
      expect(dashboardRepository.fetchCalls, 2);

      retryCompleter.complete(_dashboard(label: 'Retry'));
      await retryA;
      await retryB;
      await _flush();

      expect(subscription.read().status, PlatformDashboardStatus.data);
      expect(
        subscription.read().dashboard?.recentInstitutions.single.name,
        'Retry School',
      );
      expect(dashboardRepository.fetchCalls, 2);
    });

    test(
      'stale Session A completion cannot overwrite logged-out state',
      () async {
        final dashboardA = Completer<PlatformDashboard>();
        final dashboardRepository = FakePlatformDashboardRepository();
        dashboardRepository.onFetch = () => dashboardA.future;
        final authController = FakeAuthSessionController.authenticated(
          _owner('owner-a'),
        );
        final container = _container(
          authController: authController,
          dashboardRepository: dashboardRepository,
        );
        final subscription = _listen(container);

        await _flush();
        expect(subscription.read().status, PlatformDashboardStatus.loading);
        expect(dashboardRepository.fetchCalls, 1);

        await container.read(authSessionControllerProvider.notifier).signOut();
        await _flush();
        expect(subscription.read().status, PlatformDashboardStatus.initial);

        dashboardA.complete(_dashboard(label: 'Owner A'));
        await _flush();
        expect(subscription.read().hasData, isFalse);
        expect(findDataName(subscription), isNull);
      },
    );

    test(
      'auth and status failures request accepted session reconciliation',
      () async {
        final cases = [
          (statusCode: 401, code: 'authentication_required'),
          (statusCode: 403, code: 'password_change_required'),
          (statusCode: 403, code: 'user_inactive'),
          (statusCode: 403, code: 'institution_inactive'),
        ];

        for (final testCase in cases) {
          final authController =
              FakeAuthSessionController.authenticated(_owner('owner-a'))
                ..onBootstrap = () =>
                    testCase.code == 'password_change_required'
                    ? AuthSessionState.authenticated(
                        _owner('owner-a', mustChangePassword: true),
                      )
                    : const AuthSessionState.unauthenticated();
          final dashboardRepository = FakePlatformDashboardRepository(
            onFetch: () async => throw _serverFailure(
              testCase.code,
              statusCode: testCase.statusCode,
            ),
          );
          final container = _container(
            authController: authController,
            dashboardRepository: dashboardRepository,
          );
          _listen(container);

          await _flush();

          expect(authController.bootstrapCalls, 1);
          final session = container.read(authSessionControllerProvider);
          if (testCase.code == 'password_change_required') {
            expect(session.status, AuthSessionStatus.authenticated);
            expect(session.user?.mustChangePassword, isTrue);
          } else {
            expect(session.status, AuthSessionStatus.unauthenticated);
          }
        }
      },
    );
  });
}

ProviderContainer _container({
  required FakeAuthSessionController authController,
  required FakePlatformDashboardRepository dashboardRepository,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(() => authController),
      platformDashboardRepositoryProvider.overrideWithValue(
        dashboardRepository,
      ),
    ],
  );
  addTearDown(container.dispose);

  return container;
}

ProviderSubscription<PlatformDashboardState> _listen(
  ProviderContainer container,
) {
  final subscription = container.listen(
    platformDashboardControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);

  return subscription;
}

String? findDataName(
  ProviderSubscription<PlatformDashboardState> subscription,
) {
  return subscription.read().dashboard?.recentInstitutions.single.name;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
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
        recentInstitutions ??
        [
          RecentPlatformInstitution(
            id: '00000000-0000-0000-0000-000000000001',
            name: '$label School',
            type: PlatformInstitutionType.school,
            status: PlatformInstitutionStatus.active,
            createdAt: DateTime.utc(2026, 8, 1, 10),
          ),
        ],
  );
}

AuthUser _owner(String loginName, {bool mustChangePassword = false}) {
  return _user(
    loginName: loginName,
    role: UserRole.platformOwner,
    fullName: '$loginName User',
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

ApiRequestException _serverFailure(String code, {required int statusCode}) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: statusCode,
      error: ApiErrorResponse(
        message: 'Server message is not used for dashboard state logic.',
        code: code,
        fieldErrors: const {},
        requestId: 'req-1',
      ),
    ),
  );
}

ApiRequestException _localFailure(ApiFailureKind kind) {
  return ApiRequestException(
    ApiFailure.local(kind: kind, message: 'Local dashboard failure.'),
  );
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

class FakeAuthSessionController extends AuthSessionController {
  FakeAuthSessionController(this.initialState);

  factory FakeAuthSessionController.authenticated(AuthUser user) {
    return FakeAuthSessionController(AuthSessionState.authenticated(user));
  }

  final AuthSessionState initialState;
  AuthSessionState Function()? onBootstrap;
  AuthSessionState Function(String login, String password)? onSignIn;
  var bootstrapCalls = 0;
  var signInCalls = 0;
  var signOutCalls = 0;

  @override
  AuthSessionState build() {
    return initialState;
  }

  @override
  Future<void> bootstrap() async {
    bootstrapCalls += 1;
    final nextState = onBootstrap?.call();
    if (nextState != null) {
      state = nextState;
    }
  }

  @override
  Future<void> signIn({required String login, required String password}) async {
    signInCalls += 1;
    state =
        onSignIn?.call(login, password) ??
        AuthSessionState.authenticated(_owner(login));
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    state = const AuthSessionState.unauthenticated();
  }
}
