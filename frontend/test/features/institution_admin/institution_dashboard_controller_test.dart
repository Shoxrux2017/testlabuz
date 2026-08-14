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
import 'package:testlabuz_client/features/institution_admin/application/institution_dashboard_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_dashboard_state.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_dashboard_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_dashboard.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_dashboard_repository.dart';

void main() {
  group('InstitutionDashboardController', () {
    test(
      'eligible session loads once and maps non-zero partial-zero and all-zero data',
      () async {
        final dashboards = [
          const InstitutionDashboard(teachers: 3, students: 20, parents: 12),
          const InstitutionDashboard(teachers: 0, students: 8, parents: 0),
          const InstitutionDashboard(teachers: 0, students: 0, parents: 0),
        ];

        for (final dashboard in dashboards) {
          final repository = FakeInstitutionDashboardRepository(
            onFetch: (_) async => dashboard,
          );
          final container = _container(
            authController: FakeAuthSessionController.authenticated(_admin()),
            dashboardRepository: repository,
          );
          final subscription = _listen(container);

          await _flush();

          expect(subscription.read().status, InstitutionDashboardStatus.data);
          expect(subscription.read().dashboard, same(dashboard));
          expect(
            subscription.read().hasNoUsers,
            dashboard.teachers == 0 &&
                dashboard.students == 0 &&
                dashboard.parents == 0,
          );
          expect(repository.fetchCalls, 1);

          container.read(institutionDashboardControllerProvider);
          container.read(institutionDashboardControllerProvider);
          expect(repository.fetchCalls, 1);
        }
      },
    );

    test(
      'equivalent authenticated emission preserves a pending initial load',
      () async {
        final initialRequest = Completer<InstitutionDashboard>();
        final repository = FakeInstitutionDashboardRepository(
          onFetch: (_) => initialRequest.future,
        );
        final authController = FakeAuthSessionController.authenticated(
          _admin(),
        );
        final container = _container(
          authController: authController,
          dashboardRepository: repository,
        );
        final subscription = _listen(container);
        var authEmissionCount = 0;
        final authSubscription = container.listen(
          authSessionControllerProvider,
          (_, _) => authEmissionCount += 1,
        );
        addTearDown(authSubscription.close);
        await _flush();

        expect(subscription.read().status, InstitutionDashboardStatus.loading);
        expect(repository.fetchCalls, 1);

        authController.setSession(AuthSessionState.authenticated(_admin()));
        await _flush();

        expect(subscription.read().status, InstitutionDashboardStatus.loading);
        expect(repository.fetchCalls, 1);
        expect(authEmissionCount, 1);

        initialRequest.complete(
          const InstitutionDashboard(teachers: 7, students: 70, parents: 50),
        );
        await _flush();

        expect(subscription.read().status, InstitutionDashboardStatus.data);
        expect(subscription.read().dashboard?.teachers, 7);
        expect(subscription.read().dashboard?.students, 70);
        expect(subscription.read().dashboard?.parents, 50);
        expect(repository.fetchCalls, 1);
      },
    );

    test(
      'equivalent authenticated emission preserves a pending refresh',
      () async {
        final refreshRequest = Completer<InstitutionDashboard>();
        final repository = FakeInstitutionDashboardRepository(
          onFetch: (call) async {
            if (call == 1) {
              return const InstitutionDashboard(
                teachers: 1,
                students: 2,
                parents: 3,
              );
            }

            return refreshRequest.future;
          },
        );
        final authController = FakeAuthSessionController.authenticated(
          _admin(),
        );
        final container = _container(
          authController: authController,
          dashboardRepository: repository,
        );
        final subscription = _listen(container);
        var authEmissionCount = 0;
        final authSubscription = container.listen(
          authSessionControllerProvider,
          (_, _) => authEmissionCount += 1,
        );
        addTearDown(authSubscription.close);
        await _flush();

        final refreshA = container
            .read(institutionDashboardControllerProvider.notifier)
            .refresh();
        final refreshB = container
            .read(institutionDashboardControllerProvider.notifier)
            .refresh();
        expect(subscription.read().status, InstitutionDashboardStatus.loading);
        expect(repository.fetchCalls, 2);

        authController.setSession(AuthSessionState.authenticated(_admin()));
        await _flush();

        expect(subscription.read().status, InstitutionDashboardStatus.loading);
        expect(repository.fetchCalls, 2);
        expect(authEmissionCount, 1);

        refreshRequest.complete(
          const InstitutionDashboard(teachers: 8, students: 80, parents: 60),
        );
        await refreshA;
        await refreshB;
        await _flush();

        expect(subscription.read().status, InstitutionDashboardStatus.data);
        expect(subscription.read().dashboard?.teachers, 8);
        expect(subscription.read().dashboard?.students, 80);
        expect(subscription.read().dashboard?.parents, 60);
        expect(repository.fetchCalls, 2);
      },
    );

    test(
      'equivalent authenticated emission preserves a pending retry',
      () async {
        final retryRequest = Completer<InstitutionDashboard>();
        final repository = FakeInstitutionDashboardRepository(
          onFetch: (call) async {
            if (call == 1) {
              throw _localFailure(ApiFailureKind.connection);
            }

            return retryRequest.future;
          },
        );
        final authController = FakeAuthSessionController.authenticated(
          _admin(),
        );
        final container = _container(
          authController: authController,
          dashboardRepository: repository,
        );
        final subscription = _listen(container);
        var authEmissionCount = 0;
        final authSubscription = container.listen(
          authSessionControllerProvider,
          (_, _) => authEmissionCount += 1,
        );
        addTearDown(authSubscription.close);
        await _flush();

        expect(subscription.read().status, InstitutionDashboardStatus.error);
        final retryA = container
            .read(institutionDashboardControllerProvider.notifier)
            .retry();
        final retryB = container
            .read(institutionDashboardControllerProvider.notifier)
            .retry();
        expect(subscription.read().status, InstitutionDashboardStatus.error);
        expect(subscription.read().isRetryInFlight, isTrue);
        expect(repository.fetchCalls, 2);

        authController.setSession(AuthSessionState.authenticated(_admin()));
        await _flush();

        expect(subscription.read().status, InstitutionDashboardStatus.error);
        expect(subscription.read().isRetryInFlight, isTrue);
        expect(repository.fetchCalls, 2);
        expect(authEmissionCount, 1);

        retryRequest.complete(
          const InstitutionDashboard(teachers: 9, students: 90, parents: 70),
        );
        await retryA;
        await retryB;
        await _flush();

        expect(subscription.read().status, InstitutionDashboardStatus.data);
        expect(subscription.read().dashboard?.teachers, 9);
        expect(subscription.read().dashboard?.students, 90);
        expect(subscription.read().dashboard?.parents, 70);
        expect(repository.fetchCalls, 2);
      },
    );

    test(
      'refresh removes stale data, deduplicates, and atomically replaces all counts',
      () async {
        final refreshCompleter = Completer<InstitutionDashboard>();
        final repository = FakeInstitutionDashboardRepository(
          onFetch: (call) async {
            if (call == 1) {
              return const InstitutionDashboard(
                teachers: 1,
                students: 2,
                parents: 3,
              );
            }

            return refreshCompleter.future;
          },
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(_admin()),
          dashboardRepository: repository,
        );
        final subscription = _listen(container);
        await _flush();

        final refreshA = container
            .read(institutionDashboardControllerProvider.notifier)
            .refresh();
        final refreshB = container
            .read(institutionDashboardControllerProvider.notifier)
            .refresh();

        expect(subscription.read().status, InstitutionDashboardStatus.loading);
        expect(subscription.read().dashboard, isNull);
        expect(repository.fetchCalls, 2);

        refreshCompleter.complete(
          const InstitutionDashboard(teachers: 10, students: 20, parents: 30),
        );
        await refreshA;
        await refreshB;
        await _flush();

        expect(subscription.read().status, InstitutionDashboardStatus.data);
        expect(subscription.read().dashboard?.teachers, 10);
        expect(subscription.read().dashboard?.students, 20);
        expect(subscription.read().dashboard?.parents, 30);
        expect(repository.fetchCalls, 2);
      },
    );

    test('refresh failure shows only the current error', () async {
      final repository = FakeInstitutionDashboardRepository(
        onFetch: (call) async {
          if (call == 1) {
            return const InstitutionDashboard(
              teachers: 1,
              students: 2,
              parents: 3,
            );
          }

          throw _localFailure(ApiFailureKind.timeout);
        },
      );
      final container = _container(
        authController: FakeAuthSessionController.authenticated(_admin()),
        dashboardRepository: repository,
      );
      final subscription = _listen(container);
      await _flush();

      await container
          .read(institutionDashboardControllerProvider.notifier)
          .refresh();

      expect(subscription.read().status, InstitutionDashboardStatus.error);
      expect(subscription.read().dashboard, isNull);
      expect(subscription.read().failure?.kind, ApiFailureKind.timeout);
    });

    test(
      'unexpected repository failure becomes a safe unknown error',
      () async {
        final repository = FakeInstitutionDashboardRepository(
          onFetch: (_) => throw StateError('private implementation detail'),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(_admin()),
          dashboardRepository: repository,
        );
        final subscription = _listen(container);

        await _flush();

        expect(subscription.read().status, InstitutionDashboardStatus.error);
        expect(subscription.read().dashboard, isNull);
        expect(subscription.read().failure?.kind, ApiFailureKind.unknown);
        expect(
          subscription.read().failure?.message,
          isNot(contains('private implementation detail')),
        );
      },
    );

    test(
      'retry retains error, disables duplicates, then succeeds or re-enables',
      () async {
        final retryCompleter = Completer<InstitutionDashboard>();
        final repository = FakeInstitutionDashboardRepository();
        repository.onFetch = (call) async {
          if (call == 1 || call == 3) {
            throw _localFailure(ApiFailureKind.connection);
          }

          return retryCompleter.future;
        };
        final container = _container(
          authController: FakeAuthSessionController.authenticated(_admin()),
          dashboardRepository: repository,
        );
        final subscription = _listen(container);
        await _flush();

        expect(subscription.read().status, InstitutionDashboardStatus.error);
        final retryA = container
            .read(institutionDashboardControllerProvider.notifier)
            .retry();
        final retryB = container
            .read(institutionDashboardControllerProvider.notifier)
            .retry();
        expect(subscription.read().status, InstitutionDashboardStatus.error);
        expect(subscription.read().isRetryInFlight, isTrue);
        expect(subscription.read().failure?.kind, ApiFailureKind.connection);
        expect(repository.fetchCalls, 2);

        retryCompleter.complete(
          const InstitutionDashboard(teachers: 4, students: 5, parents: 6),
        );
        await retryA;
        await retryB;
        await _flush();
        expect(subscription.read().status, InstitutionDashboardStatus.data);

        await container
            .read(institutionDashboardControllerProvider.notifier)
            .refresh();
        expect(subscription.read().status, InstitutionDashboardStatus.error);
        expect(subscription.read().isRetryInFlight, isFalse);
      },
    );

    test(
      'every ineligible session invariant issues zero dashboard requests',
      () async {
        final failure = ApiFailure.local(
          kind: ApiFailureKind.connection,
          message: 'Bootstrap unavailable.',
        );
        final cases = <AuthSessionState>[
          const AuthSessionState.initial(),
          const AuthSessionState.bootstrapping(),
          const AuthSessionState.unauthenticated(),
          const AuthSessionState.authenticating(),
          AuthSessionState.bootstrapFailure(failure),
          AuthSessionState.authenticated(_user(role: UserRole.teacher)),
          AuthSessionState.authenticated(_admin(isActive: false)),
          AuthSessionState.authenticated(_admin(mustChangePassword: true)),
          AuthSessionState.authenticated(_admin(institutionId: null)),
          AuthSessionState.authenticated(_admin(institutionId: '')),
          AuthSessionState.authenticated(_admin(includeInstitution: false)),
          AuthSessionState.authenticated(
            _admin(
              institution: const AuthInstitution(
                id: 'institution-b',
                name: 'Institution B',
                status: 'active',
                timezone: 'Asia/Tashkent',
              ),
            ),
          ),
          AuthSessionState.authenticated(
            _admin(
              institution: const AuthInstitution(
                id: 'institution-a',
                name: 'Institution A',
                status: 'inactive',
                timezone: 'Asia/Tashkent',
              ),
            ),
          ),
        ];

        for (final session in cases) {
          final repository = FakeInstitutionDashboardRepository();
          final container = _container(
            authController: FakeAuthSessionController(session),
            dashboardRepository: repository,
          );
          final subscription = _listen(container);

          await _flush();

          expect(
            subscription.read().status,
            InstitutionDashboardStatus.initial,
          );
          expect(repository.fetchCalls, 0, reason: '${session.status}');
        }
      },
    );

    test('logout and cross-role switch reject an earlier completion', () async {
      final oldRequest = Completer<InstitutionDashboard>();
      final repository = FakeInstitutionDashboardRepository(
        onFetch: (_) => oldRequest.future,
      );
      final authController = FakeAuthSessionController.authenticated(_admin());
      final container = _container(
        authController: authController,
        dashboardRepository: repository,
      );
      final subscription = _listen(container);
      await _flush();

      authController.setSession(const AuthSessionState.unauthenticated());
      await _flush();
      expect(subscription.read().status, InstitutionDashboardStatus.initial);

      oldRequest.complete(
        const InstitutionDashboard(teachers: 99, students: 99, parents: 99),
      );
      await _flush();
      expect(subscription.read().hasData, isFalse);

      authController.setSession(
        AuthSessionState.authenticated(_user(role: UserRole.teacher)),
      );
      await _flush();
      expect(subscription.read().status, InstitutionDashboardStatus.initial);
      expect(repository.fetchCalls, 1);
    });

    test(
      'Institution Admin A to B accepts only B and rejects stale A refresh',
      () async {
        final refreshA = Completer<InstitutionDashboard>();
        final requestB = Completer<InstitutionDashboard>();
        final repository = FakeInstitutionDashboardRepository(
          onFetch: (call) async {
            if (call == 1) {
              return const InstitutionDashboard(
                teachers: 1,
                students: 1,
                parents: 1,
              );
            }
            if (call == 2) {
              return refreshA.future;
            }

            return requestB.future;
          },
        );
        final authController = FakeAuthSessionController.authenticated(
          _admin(),
        );
        final container = _container(
          authController: authController,
          dashboardRepository: repository,
        );
        final subscription = _listen(container);
        await _flush();

        unawaited(
          container
              .read(institutionDashboardControllerProvider.notifier)
              .refresh(),
        );
        await _flush();
        authController.setSession(
          AuthSessionState.authenticated(
            _admin(
              id: 'admin-b',
              institutionId: 'institution-b',
              institution: const AuthInstitution(
                id: 'institution-b',
                name: 'Institution B',
                status: 'active',
                timezone: 'Asia/Tashkent',
              ),
            ),
          ),
        );
        await _flush();
        expect(repository.fetchCalls, 3);

        requestB.complete(
          const InstitutionDashboard(teachers: 2, students: 20, parents: 12),
        );
        await _flush();
        expect(subscription.read().dashboard?.teachers, 2);

        refreshA.complete(
          const InstitutionDashboard(
            teachers: 100,
            students: 100,
            parents: 100,
          ),
        );
        await _flush();
        expect(subscription.read().dashboard?.teachers, 2);
        expect(subscription.read().dashboard?.students, 20);
      },
    );

    test(
      'provider disposal rejects late completion without publishing data',
      () async {
        final request = Completer<InstitutionDashboard>();
        final repository = FakeInstitutionDashboardRepository(
          onFetch: (_) => request.future,
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(_admin()),
          dashboardRepository: repository,
        );
        final states = <InstitutionDashboardState>[];
        final subscription = container.listen(
          institutionDashboardControllerProvider,
          (_, next) => states.add(next),
          fireImmediately: true,
        );
        await _flush();
        expect(repository.fetchCalls, 1);

        subscription.close();
        await _flush();
        request.complete(
          const InstitutionDashboard(teachers: 9, students: 9, parents: 9),
        );
        await _flush();

        expect(states.where((state) => state.hasData), isEmpty);
      },
    );

    test(
      'only current lifecycle failures reconcile and 401 remains central',
      () async {
        final cases = [
          (code: 'authentication_required', expectedBootstraps: 0),
          (code: 'password_change_required', expectedBootstraps: 1),
          (code: 'user_inactive', expectedBootstraps: 1),
          (code: 'institution_inactive', expectedBootstraps: 1),
        ];

        for (final testCase in cases) {
          final authController = FakeAuthSessionController.authenticated(
            _admin(),
          );
          final repository = FakeInstitutionDashboardRepository(
            onFetch: (_) async => throw _serverFailure(testCase.code),
          );
          final container = _container(
            authController: authController,
            dashboardRepository: repository,
          );
          _listen(container);

          await _flush();
          expect(authController.bootstrapCalls, testCase.expectedBootstraps);
        }

        final staleFailure = Completer<InstitutionDashboard>();
        final staleAuthController = FakeAuthSessionController.authenticated(
          _admin(),
        );
        final staleContainer = _container(
          authController: staleAuthController,
          dashboardRepository: FakeInstitutionDashboardRepository(
            onFetch: (_) => staleFailure.future,
          ),
        );
        _listen(staleContainer);
        await _flush();
        staleAuthController.setSession(
          const AuthSessionState.unauthenticated(),
        );
        staleFailure.completeError(_serverFailure('user_inactive'));
        await _flush();
        expect(staleAuthController.bootstrapCalls, 0);
      },
    );
  });
}

ProviderContainer _container({
  required FakeAuthSessionController authController,
  required FakeInstitutionDashboardRepository dashboardRepository,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(() => authController),
      institutionDashboardRepositoryProvider.overrideWithValue(
        dashboardRepository,
      ),
    ],
  );
  addTearDown(container.dispose);

  return container;
}

ProviderSubscription<InstitutionDashboardState> _listen(
  ProviderContainer container,
) {
  final subscription = container.listen(
    institutionDashboardControllerProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);

  return subscription;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

AuthUser _admin({
  String id = 'admin-a',
  String? institutionId = 'institution-a',
  bool isActive = true,
  bool mustChangePassword = false,
  bool includeInstitution = true,
  AuthInstitution? institution,
}) {
  return AuthUser(
    id: id,
    institutionId: institutionId,
    role: UserRole.institutionAdmin,
    fullName: 'Admin User',
    loginName: 'admin',
    email: null,
    phone: null,
    isActive: isActive,
    mustChangePassword: mustChangePassword,
    institution: includeInstitution
        ? institution ??
              const AuthInstitution(
                id: 'institution-a',
                name: 'Institution A',
                status: 'active',
                timezone: 'Asia/Tashkent',
              )
        : null,
  );
}

AuthUser _user({required UserRole role}) {
  return AuthUser(
    id: '${role.value}-user',
    institutionId: role == UserRole.platformOwner ? null : 'institution-a',
    role: role,
    fullName: '${role.value} User',
    loginName: role.value,
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: false,
    institution: role == UserRole.platformOwner
        ? null
        : const AuthInstitution(
            id: 'institution-a',
            name: 'Institution A',
            status: 'active',
            timezone: 'Asia/Tashkent',
          ),
  );
}

ApiRequestException _localFailure(ApiFailureKind kind) {
  return ApiRequestException(
    ApiFailure.local(kind: kind, message: 'Local dashboard failure.'),
  );
}

ApiRequestException _serverFailure(String code) {
  return ApiRequestException(
    ApiFailure.fromServerError(
      statusCode: code == 'authentication_required' ? 401 : 403,
      error: ApiErrorResponse(
        message: 'Server dashboard failure.',
        code: code,
        fieldErrors: const {},
        requestId: 'req-private',
      ),
    ),
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

class FakeAuthSessionController extends AuthSessionController {
  FakeAuthSessionController(this.initialState);

  factory FakeAuthSessionController.authenticated(AuthUser user) {
    return FakeAuthSessionController(AuthSessionState.authenticated(user));
  }

  final AuthSessionState initialState;
  AuthSessionState Function()? onBootstrap;
  var bootstrapCalls = 0;

  @override
  AuthSessionState build() => initialState;

  void setSession(AuthSessionState nextState) {
    state = nextState;
  }

  @override
  Future<void> bootstrap() async {
    bootstrapCalls += 1;
    final nextState = onBootstrap?.call();
    if (nextState != null) {
      state = nextState;
    }
  }
}
