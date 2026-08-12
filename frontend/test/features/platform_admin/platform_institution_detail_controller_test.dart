import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_detail_controller.dart';
import 'package:testlabuz_client/features/platform_admin/application/platform_institution_detail_state.dart';
import 'package:testlabuz_client/features/platform_admin/data/platform_institution_detail_repository_impl.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail.dart';
import 'package:testlabuz_client/features/platform_admin/domain/platform_institution_detail_repository.dart';

void main() {
  group('PlatformInstitutionDetailController', () {
    test(
      'eligible owner detail loads exactly once and ignores rebuild reads',
      () async {
        final owner = _owner('owner-a');
        final detailCompleter = Completer<PlatformInstitutionDetail>();
        final repository = FakePlatformInstitutionDetailRepository(
          onFetch: (_) => detailCompleter.future,
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);

        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionDetailStatus.loading,
        );
        expect(repository.fetchCalls, 1);
        expect(repository.institutionIds.single, key.institutionId);

        container.read(platformInstitutionDetailControllerProvider(key));
        container.read(platformInstitutionDetailControllerProvider(key));
        expect(repository.fetchCalls, 1);

        detailCompleter.complete(_detail(label: 'Loaded'));
        await _flush();

        final state = subscription.read();
        expect(state.status, PlatformInstitutionDetailStatus.data);
        expect(state.detail?.name, 'Loaded School');
        expect(repository.fetchCalls, 1);
      },
    );

    test(
      'retryable failure has one duplicate-protected retry request',
      () async {
        final owner = _owner('owner-a');
        final retryCompleter = Completer<PlatformInstitutionDetail>();
        final repository = FakePlatformInstitutionDetailRepository();
        repository.onFetch = (_) {
          if (repository.fetchCalls == 1) {
            throw _localFailure(ApiFailureKind.connection);
          }

          return retryCompleter.future;
        };
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);

        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionDetailStatus.error,
        );
        expect(repository.fetchCalls, 1);

        final retryA = container
            .read(platformInstitutionDetailControllerProvider(key).notifier)
            .retry();
        final retryB = container
            .read(platformInstitutionDetailControllerProvider(key).notifier)
            .retry();
        expect(subscription.read().isRetryInFlight, isTrue);
        expect(repository.fetchCalls, 2);

        retryCompleter.complete(_detail(label: 'Retry'));
        await retryA;
        await retryB;
        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionDetailStatus.data,
        );
        expect(subscription.read().detail?.name, 'Retry School');
        expect(repository.fetchCalls, 2);
      },
    );

    test(
      'resource_not_found 404 becomes non-retryable not-found state',
      () async {
        final owner = _owner('owner-a');
        final repository = FakePlatformInstitutionDetailRepository(
          onFetch: (_) async => throw _serverFailure(
            ApiErrorCodes.resourceNotFound,
            statusCode: 404,
          ),
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final key = _key(owner);
        final subscription = _listen(container, key);

        await _flush();

        expect(
          subscription.read().status,
          PlatformInstitutionDetailStatus.notFound,
        );
        await container
            .read(platformInstitutionDetailControllerProvider(key).notifier)
            .retry();
        await _flush();
        expect(repository.fetchCalls, 1);
      },
    );

    test(
      'unexpected validation and forbidden failures stay safe errors',
      () async {
        final cases = [
          (code: ApiErrorCodes.validationFailed, statusCode: 422),
          (code: ApiErrorCodes.forbidden, statusCode: 403),
        ];

        for (final testCase in cases) {
          final owner = _owner('owner-a');
          final repository = FakePlatformInstitutionDetailRepository(
            onFetch: (_) async => throw _serverFailure(
              testCase.code,
              statusCode: testCase.statusCode,
            ),
          );
          final authController = FakeAuthSessionController.authenticated(owner);
          final container = _container(
            authController: authController,
            repository: repository,
          );
          final subscription = _listen(container, _key(owner));

          await _flush();

          expect(
            subscription.read().status,
            PlatformInstitutionDetailStatus.error,
          );
          expect(subscription.read().failure?.serverCode, testCase.code);
          expect(authController.bootstrapCalls, 0);
        }
      },
    );

    test(
      'auth and account-status failures request accepted reconciliation',
      () async {
        final cases = [
          (statusCode: 401, code: ApiErrorCodes.authenticationRequired),
          (statusCode: 403, code: ApiErrorCodes.passwordChangeRequired),
          (statusCode: 403, code: ApiErrorCodes.userInactive),
          (statusCode: 403, code: ApiErrorCodes.institutionInactive),
        ];

        for (final testCase in cases) {
          final owner = _owner('owner-a');
          final authController = FakeAuthSessionController.authenticated(owner)
            ..onBootstrap = () =>
                testCase.code == ApiErrorCodes.passwordChangeRequired
                ? AuthSessionState.authenticated(
                    _owner('owner-a', mustChangePassword: true),
                  )
                : const AuthSessionState.unauthenticated();
          final repository = FakePlatformInstitutionDetailRepository(
            onFetch: (_) async => throw _serverFailure(
              testCase.code,
              statusCode: testCase.statusCode,
            ),
          );
          final container = _container(
            authController: authController,
            repository: repository,
          );
          _listen(container, _key(owner));

          await _flush();

          expect(authController.bootstrapCalls, 1);
          final session = container.read(authSessionControllerProvider);
          if (testCase.code == ApiErrorCodes.passwordChangeRequired) {
            expect(session.status, AuthSessionStatus.authenticated);
            expect(session.user?.mustChangePassword, isTrue);
          } else {
            expect(session.status, AuthSessionStatus.unauthenticated);
          }
        }
      },
    );

    test(
      'route A to B disposal prevents late A completion from replacing B',
      () async {
        final owner = _owner('owner-a');
        final institutionA = Completer<PlatformInstitutionDetail>();
        final institutionB = Completer<PlatformInstitutionDetail>();
        final repository = FakePlatformInstitutionDetailRepository(
          onFetch: (institutionId) {
            if (institutionId == _institutionIdA) {
              return institutionA.future;
            }

            return institutionB.future;
          },
        );
        final container = _container(
          authController: FakeAuthSessionController.authenticated(owner),
          repository: repository,
        );
        final keyA = _key(owner, institutionId: _institutionIdA);
        final keyB = _key(owner, institutionId: _institutionIdB);
        final subscriptionA = _listen(container, keyA);

        await _flush();
        expect(repository.institutionIds, [_institutionIdA]);
        subscriptionA.close();
        await _flush();

        final subscriptionB = _listen(container, keyB);
        await _flush();
        expect(repository.institutionIds, [_institutionIdA, _institutionIdB]);

        institutionB.complete(_detail(id: _institutionIdB, label: 'B'));
        await _flush();
        expect(subscriptionB.read().detail?.name, 'B School');

        institutionA.complete(_detail(id: _institutionIdA, label: 'A'));
        await _flush();
        expect(subscriptionB.read().detail?.name, 'B School');
      },
    );

    test('late A failure cannot replace newer B detail state', () async {
      final owner = _owner('owner-a');
      final institutionA = Completer<PlatformInstitutionDetail>();
      final institutionB = Completer<PlatformInstitutionDetail>();
      final repository = FakePlatformInstitutionDetailRepository(
        onFetch: (institutionId) {
          if (institutionId == _institutionIdA) {
            return institutionA.future;
          }

          return institutionB.future;
        },
      );
      final container = _container(
        authController: FakeAuthSessionController.authenticated(owner),
        repository: repository,
      );
      final subscriptionA = _listen(
        container,
        _key(owner, institutionId: _institutionIdA),
      );

      await _flush();
      subscriptionA.close();
      await _flush();

      final subscriptionB = _listen(
        container,
        _key(owner, institutionId: _institutionIdB),
      );
      await _flush();

      institutionB.complete(_detail(id: _institutionIdB, label: 'B'));
      await _flush();
      expect(subscriptionB.read().detail?.name, 'B School');

      institutionA.completeError(_localFailure(ApiFailureKind.connection));
      await _flush();
      expect(subscriptionB.read().status, PlatformInstitutionDetailStatus.data);
      expect(subscriptionB.read().detail?.name, 'B School');
    });

    test(
      'logout account switch disposal and new session refetch same UUID',
      () async {
        final ownerA = _owner('owner-a');
        final first = Completer<PlatformInstitutionDetail>();
        final repository = FakePlatformInstitutionDetailRepository(
          onFetch: (_) => first.future,
        );
        final authController = FakeAuthSessionController.authenticated(ownerA);
        final container = _container(
          authController: authController,
          repository: repository,
        );
        final keyA = _key(ownerA);
        final subscriptionA = _listen(container, keyA);

        await _flush();
        expect(
          subscriptionA.read().status,
          PlatformInstitutionDetailStatus.loading,
        );
        expect(repository.fetchCalls, 1);

        await container.read(authSessionControllerProvider.notifier).signOut();
        await _flush();
        expect(
          subscriptionA.read().status,
          PlatformInstitutionDetailStatus.initial,
        );

        first.complete(_detail(label: 'Old Owner'));
        await _flush();
        expect(subscriptionA.read().detail, isNull);

        final sameAccountNewSession = _owner('owner-a');
        final second = Completer<PlatformInstitutionDetail>();
        repository.onFetch = (_) => second.future;
        authController.setAuthenticated(sameAccountNewSession);
        final keySameAccount = _key(sameAccountNewSession);
        final subscriptionSameAccount = _listen(container, keySameAccount);
        await _flush();

        expect(repository.institutionIds, [_institutionIdA, _institutionIdA]);

        second.complete(_detail(label: 'Same Account New Session'));
        await _flush();
        expect(
          subscriptionSameAccount.read().detail?.name,
          'Same Account New Session School',
        );

        final ownerB = _owner('owner-b');
        final third = Completer<PlatformInstitutionDetail>();
        repository.onFetch = (_) => third.future;
        authController.setAuthenticated(ownerB);
        final keyB = _key(ownerB);
        final subscriptionB = _listen(container, keyB);
        await _flush();
        expect(repository.institutionIds, [
          _institutionIdA,
          _institutionIdA,
          _institutionIdA,
        ]);

        third.complete(_detail(label: 'Owner B'));
        await _flush();
        expect(subscriptionB.read().detail?.name, 'Owner B School');
        expect(subscriptionSameAccount.read().detail, isNull);
      },
    );
  });
}

ProviderContainer _container({
  required FakeAuthSessionController authController,
  required FakePlatformInstitutionDetailRepository repository,
}) {
  final container = ProviderContainer(
    overrides: [
      authSessionControllerProvider.overrideWith(() => authController),
      platformInstitutionDetailRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);

  return container;
}

ProviderSubscription<PlatformInstitutionDetailState> _listen(
  ProviderContainer container,
  PlatformInstitutionDetailKey key,
) {
  final subscription = container.listen(
    platformInstitutionDetailControllerProvider(key),
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

PlatformInstitutionDetailKey _key(
  AuthUser user, {
  String institutionId = _institutionIdA,
}) {
  return PlatformInstitutionDetailKey(
    sessionUserId: user.id,
    sessionInstanceId: identityHashCode(user),
    institutionId: institutionId,
  );
}

PlatformInstitutionDetail _detail({
  String id = _institutionIdA,
  String label = 'Example',
}) {
  return PlatformInstitutionDetail(
    id: id,
    name: '$label School',
    type: PlatformInstitutionType.school,
    status: PlatformInstitutionStatus.active,
    contactEmail: 'info@example.uz',
    contactPhone: '+998901234567',
    address: 'Samarkand',
    description: 'Optional notes',
    createdAt: DateTime.utc(2026, 8, 7, 15),
    updatedAt: DateTime.utc(2026, 8, 7, 16),
    userCounts: const PlatformInstitutionUserCounts(total: 42, active: 40),
  );
}

AuthUser _owner(String loginName, {bool mustChangePassword = false}) {
  return _user(
    loginName: loginName,
    role: UserRole.platformOwner,
    mustChangePassword: mustChangePassword,
  );
}

AuthUser _user({
  required String loginName,
  required UserRole role,
  bool mustChangePassword = false,
}) {
  return AuthUser(
    id: '$loginName-id',
    institutionId: role == UserRole.platformOwner ? null : 'institution-1',
    role: role,
    fullName: '$loginName User',
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
        message: 'Server message is not used for detail state logic.',
        code: code,
        fieldErrors: const {},
        requestId: 'req-1',
      ),
    ),
  );
}

ApiRequestException _localFailure(ApiFailureKind kind) {
  return ApiRequestException(
    ApiFailure.local(kind: kind, message: 'Local institution detail failure.'),
  );
}

class FakePlatformInstitutionDetailRepository
    implements PlatformInstitutionDetailRepository {
  FakePlatformInstitutionDetailRepository({this.onFetch});

  Future<PlatformInstitutionDetail> Function(String institutionId)? onFetch;
  final institutionIds = <String>[];

  int get fetchCalls => institutionIds.length;

  @override
  Future<PlatformInstitutionDetail> fetchInstitutionDetail(
    String institutionId,
  ) {
    institutionIds.add(institutionId);

    return onFetch?.call(institutionId) ??
        Future.value(_detail(id: institutionId));
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

  void setAuthenticated(AuthUser user) {
    state = AuthSessionState.authenticated(user);
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

const _institutionIdA = '550e8400-e29b-41d4-a716-446655440000';
const _institutionIdB = '550e8400-e29b-41d4-a716-446655440001';
