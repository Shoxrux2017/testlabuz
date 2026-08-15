import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/app/device/app_device_surface.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_detail_controller.dart';
import 'package:testlabuz_client/features/institution_admin/application/institution_user_detail_state.dart';
import 'package:testlabuz_client/features/institution_admin/data/institution_user_detail_repository_impl.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user.dart';
import 'package:testlabuz_client/features/institution_admin/domain/institution_user_detail_repository.dart';

void main() {
  test(
    'eligible session loads the exact target once and refreshes once',
    () async {
      final repository = _FakeDetailRepository(
        onFetch: (target, call) async => _user(
          id: target,
          fullName: call == 1 ? 'Initial User' : 'Refreshed User',
        ),
      );
      final container = _container(repository);
      final subscription = _listen(container, _userId);
      await _flush();

      expect(repository.targets, [_userId]);
      expect(subscription.read().status, InstitutionUserDetailStatus.data);
      expect(subscription.read().user?.fullName, 'Initial User');

      final controller = container.read(
        institutionUserDetailControllerProvider(_userId).notifier,
      );
      controller.refresh();
      controller.refresh();
      await _flush();

      expect(repository.targets, [_userId, _userId]);
      expect(subscription.read().status, InstitutionUserDetailStatus.data);
      expect(subscription.read().user?.fullName, 'Refreshed User');
    },
  );

  for (final presentation in _EquivalentAuthUpdatePresentation.values) {
    test('equivalent authenticated state with the same AuthUser preserves '
        '${presentation.name} request', () async {
      final request = Completer<InstitutionUser>();
      final sessionUser = _sessionUser();
      final auth = _FakeAuthSessionController(
        AuthSessionState.authenticated(sessionUser),
      );
      final repository = _FakeDetailRepository(
        onFetch: (target, call) {
          if (presentation == _EquivalentAuthUpdatePresentation.refresh &&
              call == 1) {
            return Future.value(_user(id: target));
          }
          if (presentation == _EquivalentAuthUpdatePresentation.retry &&
              call == 1) {
            return Future.error(
              ApiRequestException(
                ApiFailure.local(
                  kind: ApiFailureKind.connection,
                  message: 'Initial retryable failure.',
                ),
              ),
            );
          }
          return request.future;
        },
      );
      final container = _container(repository, auth: auth);
      final subscription = _listen(container, _userId);
      await _flush();

      final controller = container.read(
        institutionUserDetailControllerProvider(_userId).notifier,
      );
      switch (presentation) {
        case _EquivalentAuthUpdatePresentation.initial:
          break;
        case _EquivalentAuthUpdatePresentation.refresh:
          controller.refresh();
        case _EquivalentAuthUpdatePresentation.retry:
          controller.retry();
      }

      final expectedCalls =
          presentation == _EquivalentAuthUpdatePresentation.initial ? 1 : 2;
      expect(repository.fetchCalls, expectedCalls);
      expect(
        subscription.read().status,
        presentation == _EquivalentAuthUpdatePresentation.refresh
            ? InstitutionUserDetailStatus.refreshing
            : InstitutionUserDetailStatus.loading,
      );

      auth.setSession(AuthSessionState.authenticated(sessionUser));
      await _flush();

      expect(repository.fetchCalls, expectedCalls);
      request.complete(_user(id: _userId, fullName: 'Completed User'));
      await _flush();

      expect(subscription.read().status, InstitutionUserDetailStatus.data);
      expect(subscription.read().user?.fullName, 'Completed User');
    });
  }

  test('complete ineligible session matrix issues no request', () async {
    final localFailure = ApiFailure.local(
      kind: ApiFailureKind.connection,
      message: 'Bootstrap failed.',
    );
    final cases = <({AuthSessionState session, AppDeviceSurface surface})>[
      (
        session: const AuthSessionState.initial(),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: const AuthSessionState.bootstrapping(),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: const AuthSessionState.unauthenticated(),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: const AuthSessionState.authenticating(),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.bootstrapFailure(localFailure),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(
          _sessionUser(role: UserRole.teacher),
        ),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(_sessionUser(isActive: false)),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(
          _sessionUser(mustChangePassword: true),
        ),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(
          _sessionUser(institutionId: null),
        ),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(
          _sessionUser(institutionId: '   '),
        ),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(
          _sessionUser(institution: null),
        ),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(
          _sessionUser(
            institution: const AuthInstitution(
              id: 'institution-b',
              name: 'Institution B',
              status: 'active',
              timezone: 'Asia/Tashkent',
            ),
          ),
        ),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(
          _sessionUser(
            institution: const AuthInstitution(
              id: 'institution-a',
              name: 'Institution A',
              status: 'inactive',
              timezone: 'Asia/Tashkent',
            ),
          ),
        ),
        surface: AppDeviceSurface.desktop,
      ),
      (
        session: AuthSessionState.authenticated(_sessionUser()),
        surface: AppDeviceSurface.mobile,
      ),
      (
        session: AuthSessionState.authenticated(_sessionUser()),
        surface: AppDeviceSurface.unsupported,
      ),
    ];

    for (final failureCase in cases) {
      final repository = _FakeDetailRepository();
      final container = _container(
        repository,
        session: failureCase.session,
        surface: failureCase.surface,
      );
      final subscription = _listen(container, _userId);
      await _flush();

      expect(repository.fetchCalls, 0, reason: '${failureCase.session.status}');
      expect(subscription.read().hasData, isFalse);
      expect(subscription.read().status, InstitutionUserDetailStatus.initial);
    }
  });

  test(
    'malformed direct targets fail closed while valid case is preserved',
    () async {
      final repository = _FakeDetailRepository();
      final invalidTargets = const [
        '',
        '   ',
        'new',
        'not-a-uuid',
        '550e8400-e29b-41d4-a716-446655440000/extra',
        '550e8400-e29b-41d4-a716-446655440000?private=true',
        '550e8400-e29b-41d4-a716-446655440000%2Fextra',
      ];

      for (final target in invalidTargets) {
        final container = _container(repository);
        final subscription = _listen(container, target);
        await _flush();

        expect(
          subscription.read().status,
          InstitutionUserDetailStatus.localUnavailableTarget,
          reason: target,
        );
        expect(subscription.read().hasData, isFalse);
      }
      expect(repository.fetchCalls, 0);

      final validContainer = _container(repository);
      final valid = _listen(validContainer, _upperUserId);
      await _flush();

      expect(repository.targets, [_upperUserId]);
      expect(valid.read().user?.id, _upperUserId);
    },
  );

  test(
    'accepted not found and retryability classes publish exact states',
    () async {
      final cases =
          <
            ({
              ApiFailure failure,
              InstitutionUserDetailStatus status,
              bool retryable,
            })
          >[
            (
              failure: _serverFailure(
                statusCode: 404,
                code: ApiErrorCodes.resourceNotFound,
              ),
              status: InstitutionUserDetailStatus.notFound,
              retryable: false,
            ),
            (
              failure: _serverFailure(
                statusCode: 403,
                code: ApiErrorCodes.forbidden,
              ),
              status: InstitutionUserDetailStatus.error,
              retryable: false,
            ),
            (
              failure: _serverFailure(
                statusCode: 422,
                code: ApiErrorCodes.validationFailed,
                kind: ApiFailureKind.validation,
              ),
              status: InstitutionUserDetailStatus.error,
              retryable: false,
            ),
            (
              failure: ApiFailure.local(
                kind: ApiFailureKind.invalidResponse,
                message: 'Private invalid response.',
              ),
              status: InstitutionUserDetailStatus.error,
              retryable: false,
            ),
            (
              failure: ApiFailure.local(
                kind: ApiFailureKind.connection,
                message: 'Private connection detail.',
              ),
              status: InstitutionUserDetailStatus.error,
              retryable: true,
            ),
            (
              failure: ApiFailure.local(
                kind: ApiFailureKind.timeout,
                message: 'Private timeout detail.',
              ),
              status: InstitutionUserDetailStatus.error,
              retryable: true,
            ),
            (
              failure: _serverFailure(
                statusCode: 500,
                code: ApiErrorCodes.serverError,
              ),
              status: InstitutionUserDetailStatus.error,
              retryable: true,
            ),
            (
              failure: ApiFailure.local(
                kind: ApiFailureKind.unknown,
                message: 'Private unknown detail.',
              ),
              status: InstitutionUserDetailStatus.error,
              retryable: true,
            ),
          ];

      for (final failureCase in cases) {
        final repository = _FakeDetailRepository(
          onFetch: (_, _) =>
              Future.error(ApiRequestException(failureCase.failure)),
        );
        final container = _container(repository);
        final subscription = _listen(container, _userId);
        await _flush();

        expect(subscription.read().status, failureCase.status);
        expect(subscription.read().isRetryable, failureCase.retryable);
        expect(subscription.read().hasData, isFalse);
      }
    },
  );

  test(
    'refresh keeps only same-target data while busy and replaces it',
    () async {
      final refresh = Completer<InstitutionUser>();
      final repository = _FakeDetailRepository(
        onFetch: (target, call) {
          if (call == 1) {
            return Future.value(_user(id: target, fullName: 'Initial User'));
          }
          return refresh.future;
        },
      );
      final container = _container(repository);
      final subscription = _listen(container, _userId);
      await _flush();

      final controller = container.read(
        institutionUserDetailControllerProvider(_userId).notifier,
      );
      controller.refresh();
      controller.refresh();

      expect(
        subscription.read().status,
        InstitutionUserDetailStatus.refreshing,
      );
      expect(subscription.read().user?.fullName, 'Initial User');
      expect(repository.fetchCalls, 2);

      refresh.complete(_user(id: _userId, fullName: 'Current User'));
      await _flush();

      expect(subscription.read().status, InstitutionUserDetailStatus.data);
      expect(subscription.read().user?.fullName, 'Current User');
    },
  );

  test(
    'refresh failure immediately removes previously displayed data',
    () async {
      final failures = [
        _serverFailure(statusCode: 404, code: ApiErrorCodes.resourceNotFound),
        _serverFailure(statusCode: 403, code: ApiErrorCodes.forbidden),
        ApiFailure.local(
          kind: ApiFailureKind.invalidResponse,
          message: 'Invalid response.',
        ),
        ApiFailure.local(
          kind: ApiFailureKind.connection,
          message: 'Connection failed.',
        ),
      ];

      for (final failure in failures) {
        final repository = _FakeDetailRepository(
          onFetch: (target, call) => call == 1
              ? Future.value(_user(id: target))
              : Future.error(ApiRequestException(failure)),
        );
        final container = _container(repository);
        final subscription = _listen(container, _userId);
        await _flush();

        container
            .read(institutionUserDetailControllerProvider(_userId).notifier)
            .refresh();
        await _flush();

        expect(subscription.read().hasData, isFalse, reason: '${failure.kind}');
        expect(
          subscription.read().status,
          failure.serverCode == ApiErrorCodes.resourceNotFound
              ? InstitutionUserDetailStatus.notFound
              : InstitutionUserDetailStatus.error,
        );
      }
    },
  );

  test(
    'Retry is available only for retryable error and is deduplicated',
    () async {
      final retry = Completer<InstitutionUser>();
      final repository = _FakeDetailRepository(
        onFetch: (target, call) {
          if (call == 1) {
            return Future.error(
              ApiRequestException(
                ApiFailure.local(
                  kind: ApiFailureKind.connection,
                  message: 'Private network failure.',
                ),
              ),
            );
          }
          return retry.future;
        },
      );
      final container = _container(repository);
      final subscription = _listen(container, _userId);
      await _flush();

      final controller = container.read(
        institutionUserDetailControllerProvider(_userId).notifier,
      );
      controller.retry();
      controller.retry();

      expect(repository.fetchCalls, 2);
      expect(subscription.read().status, InstitutionUserDetailStatus.loading);

      retry.complete(_user(id: _userId));
      await _flush();
      expect(subscription.read().status, InstitutionUserDetailStatus.data);

      controller.retry();
      expect(repository.fetchCalls, 2);
    },
  );

  test(
    'same-role account-instance switch ignores the prior completion',
    () async {
      final first = Completer<InstitutionUser>();
      final second = Completer<InstitutionUser>();
      final repository = _FakeDetailRepository(
        onFetch: (_, call) => call == 1 ? first.future : second.future,
      );
      final auth = _FakeAuthSessionController(
        AuthSessionState.authenticated(_sessionUser(fullName: 'Admin A')),
      );
      final container = _container(repository, auth: auth);
      final subscription = _listen(container, _userId);
      await _flush();
      expect(repository.fetchCalls, 1);

      auth.setSession(
        AuthSessionState.authenticated(_sessionUser(fullName: 'Admin B')),
      );
      await _flush();
      expect(repository.fetchCalls, 2);
      expect(subscription.read().status, InstitutionUserDetailStatus.loading);

      first.complete(_user(fullName: 'Stale User'));
      await _flush();
      expect(subscription.read().hasData, isFalse);

      second.complete(_user(fullName: 'Current User'));
      await _flush();
      expect(subscription.read().user?.fullName, 'Current User');
    },
  );

  test('cross-role switch and logout invalidate pending completion', () async {
    for (final nextSession in [
      AuthSessionState.authenticated(_sessionUser(role: UserRole.teacher)),
      const AuthSessionState.unauthenticated(),
    ]) {
      final request = Completer<InstitutionUser>();
      final repository = _FakeDetailRepository(
        onFetch: (_, _) => request.future,
      );
      final auth = _FakeAuthSessionController(
        AuthSessionState.authenticated(_sessionUser()),
      );
      final container = _container(repository, auth: auth);
      final subscription = _listen(container, _userId);
      await _flush();

      auth.setSession(nextSession);
      await _flush();
      request.complete(_user(fullName: 'Stale User'));
      await _flush();

      expect(subscription.read().status, InstitutionUserDetailStatus.initial);
      expect(subscription.read().hasData, isFalse);
      expect(repository.fetchCalls, 1);
    }
  });

  test(
    '401 clears immediately and lifecycle failures request bootstrap',
    () async {
      final cases = <({ApiFailure failure, int bootstrapCalls})>[
        (
          failure: _serverFailure(
            statusCode: 401,
            code: ApiErrorCodes.authenticationRequired,
          ),
          bootstrapCalls: 0,
        ),
        (
          failure: _serverFailure(
            statusCode: 403,
            code: ApiErrorCodes.passwordChangeRequired,
          ),
          bootstrapCalls: 1,
        ),
        (
          failure: _serverFailure(
            statusCode: 403,
            code: ApiErrorCodes.userInactive,
          ),
          bootstrapCalls: 1,
        ),
        (
          failure: _serverFailure(
            statusCode: 403,
            code: ApiErrorCodes.institutionInactive,
          ),
          bootstrapCalls: 1,
        ),
      ];

      for (final failureCase in cases) {
        final auth = _FakeAuthSessionController(
          AuthSessionState.authenticated(_sessionUser()),
        );
        final repository = _FakeDetailRepository(
          onFetch: (_, _) =>
              Future.error(ApiRequestException(failureCase.failure)),
        );
        final container = _container(repository, auth: auth);
        final subscription = _listen(container, _userId);
        await _flush();

        expect(subscription.read().status, InstitutionUserDetailStatus.initial);
        expect(subscription.read().hasData, isFalse);
        expect(auth.bootstrapCalls, failureCase.bootstrapCalls);
      }
    },
  );

  test(
    'route exit and disposal prevent stale publication and force fresh load',
    () async {
      final first = Completer<InstitutionUser>();
      final repository = _FakeDetailRepository(
        onFetch: (target, call) => call == 1
            ? first.future
            : Future.value(_user(id: target, fullName: 'Fresh User')),
      );
      final container = _container(repository);
      final subscription = _listen(container, _userId);
      await _flush();

      container
          .read(institutionUserDetailControllerProvider(_userId).notifier)
          .clearForRouteExit();
      first.complete(_user(fullName: 'Stale User'));
      await _flush();

      expect(subscription.read().status, InstitutionUserDetailStatus.initial);
      expect(subscription.read().hasData, isFalse);

      subscription.close();
      await _flush();
      final fresh = _listen(container, _userId);
      await _flush();

      expect(repository.fetchCalls, 2);
      expect(fresh.read().user?.fullName, 'Fresh User');
    },
  );
}

ProviderContainer _container(
  _FakeDetailRepository repository, {
  AuthSessionState? session,
  _FakeAuthSessionController? auth,
  AppDeviceSurface surface = AppDeviceSurface.desktop,
}) {
  final authController =
      auth ??
      _FakeAuthSessionController(
        session ?? AuthSessionState.authenticated(_sessionUser()),
      );
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(() => authController),
      appDeviceSurfaceProvider.overrideWithValue(surface),
      institutionUserDetailRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ProviderSubscription<InstitutionUserDetailState> _listen(
  ProviderContainer container,
  String userId,
) {
  final subscription = container.listen(
    institutionUserDetailControllerProvider(userId),
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(() {
    if (!subscription.closed) {
      subscription.close();
    }
  });
  return subscription;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

const _userId = '00000000-0000-0000-0000-000000000001';
const _upperUserId = 'A0B1C2D3-E4F5-6789-ABCD-EF0123456789';

InstitutionUser _user({
  String id = _userId,
  String fullName = 'Teacher Name',
}) => InstitutionUser(
  id: id,
  role: InstitutionUserRole.teacher,
  fullName: fullName,
  loginName: 'teacher01',
  email: null,
  phone: null,
  isActive: true,
  mustChangePassword: false,
  lastLoginAt: null,
  deactivatedAt: null,
  createdAt: DateTime.utc(2026, 8, 7, 15),
  updatedAt: DateTime.utc(2026, 8, 7, 16),
);

AuthUser _sessionUser({
  String id = 'admin-a',
  String? institutionId = 'institution-a',
  UserRole role = UserRole.institutionAdmin,
  String fullName = 'Admin User',
  bool isActive = true,
  bool mustChangePassword = false,
  AuthInstitution? institution = const AuthInstitution(
    id: 'institution-a',
    name: 'Institution A',
    status: 'active',
    timezone: 'Asia/Tashkent',
  ),
}) => AuthUser(
  id: id,
  institutionId: institutionId,
  role: role,
  fullName: fullName,
  loginName: 'admin',
  email: null,
  phone: null,
  isActive: isActive,
  mustChangePassword: mustChangePassword,
  institution: institution,
);

ApiFailure _serverFailure({
  required int statusCode,
  required String code,
  ApiFailureKind kind = ApiFailureKind.server,
}) {
  return ApiFailure(
    kind: kind,
    statusCode: statusCode,
    serverCode: code,
    message: 'Private server message.',
  );
}

class _FakeDetailRepository implements InstitutionUserDetailRepository {
  _FakeDetailRepository({this.onFetch});

  Future<InstitutionUser> Function(String target, int call)? onFetch;
  final targets = <String>[];

  int get fetchCalls => targets.length;

  @override
  Future<InstitutionUser> fetchUser(String userId) {
    targets.add(userId);
    return onFetch?.call(userId, fetchCalls) ?? Future.value(_user(id: userId));
  }
}

class _FakeAuthSessionController extends AuthSessionController {
  _FakeAuthSessionController(this.initialState);

  final AuthSessionState initialState;
  var bootstrapCalls = 0;

  @override
  AuthSessionState build() => initialState;

  @override
  Future<void> bootstrap() async {
    bootstrapCalls += 1;
  }

  void setSession(AuthSessionState nextState) {
    state = nextState;
  }
}

enum _EquivalentAuthUpdatePresentation { initial, refresh, retry }
