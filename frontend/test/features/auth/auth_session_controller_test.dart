import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/session_invalidation_signal.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_controller.dart';
import 'package:testlabuz_client/features/auth/application/auth_session_state.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/domain/auth_institution.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/auth_user.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';

void main() {
  group('AuthSessionController bootstrap', () {
    test('no token becomes unauthenticated without /auth/me', () async {
      final repository = FakeAuthRepository();
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      container.read(authSessionControllerProvider);
      await pumpEventQueue();

      final state = container.read(authSessionControllerProvider);
      expect(state.status, AuthSessionStatus.unauthenticated);
      expect(repository.currentUserCalls, 0);
    });

    test('valid token restores authenticated session from /auth/me', () async {
      final repository = FakeAuthRepository(storedToken: 'token-a');
      repository.onCurrentUser = () async => _user(loginName: 'teacher01');
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      container.read(authSessionControllerProvider);
      await pumpEventQueue();

      final state = container.read(authSessionControllerProvider);
      expect(state.status, AuthSessionStatus.authenticated);
      expect(state.user?.loginName, 'teacher01');
      expect(repository.currentUserCalls, 1);
    });

    test('invalid token clears token and becomes unauthenticated', () async {
      final repository = FakeAuthRepository(storedToken: 'token-a');
      repository.onCurrentUser = () async {
        throw _serverFailure(
          ApiErrorCodes.authenticationRequired,
          statusCode: 401,
        );
      };
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      container.read(authSessionControllerProvider);
      await pumpEventQueue();

      final state = container.read(authSessionControllerProvider);
      expect(state.status, AuthSessionStatus.unauthenticated);
      expect(state.failure?.serverCode, ApiErrorCodes.authenticationRequired);
      expect(repository.storedToken, isNull);
      expect(repository.clearTokenCalls, 1);
    });

    test('inactive user clears token and surfaces failure', () async {
      final repository = FakeAuthRepository(storedToken: 'token-a');
      repository.onCurrentUser = () async {
        throw _serverFailure(ApiErrorCodes.userInactive, statusCode: 403);
      };
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      container.read(authSessionControllerProvider);
      await pumpEventQueue();

      final state = container.read(authSessionControllerProvider);
      expect(state.status, AuthSessionStatus.unauthenticated);
      expect(state.failure?.serverCode, ApiErrorCodes.userInactive);
      expect(repository.storedToken, isNull);
    });

    test('inactive institution clears token and surfaces failure', () async {
      final repository = FakeAuthRepository(storedToken: 'token-a');
      repository.onCurrentUser = () async {
        throw _serverFailure(
          ApiErrorCodes.institutionInactive,
          statusCode: 403,
        );
      };
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      container.read(authSessionControllerProvider);
      await pumpEventQueue();

      final state = container.read(authSessionControllerProvider);
      expect(state.status, AuthSessionStatus.unauthenticated);
      expect(state.failure?.serverCode, ApiErrorCodes.institutionInactive);
      expect(repository.storedToken, isNull);
    });

    test(
      'transport bootstrap failure keeps token and does not authenticate',
      () async {
        final repository = FakeAuthRepository(storedToken: 'token-a');
        repository.onCurrentUser = () async {
          throw _transportFailure();
        };
        final container = _container(repository: repository);
        addTearDown(container.dispose);

        container.read(authSessionControllerProvider);
        await pumpEventQueue();

        final state = container.read(authSessionControllerProvider);
        expect(state.status, AuthSessionStatus.bootstrapFailure);
        expect(state.failure?.kind, ApiFailureKind.connection);
        expect(repository.storedToken, 'token-a');
      },
    );

    test(
      'explicit retry can recover after bootstrap transport failure',
      () async {
        final repository = FakeAuthRepository(storedToken: 'token-a');
        var shouldFail = true;
        repository.onCurrentUser = () async {
          if (shouldFail) {
            throw _transportFailure();
          }

          return _user(loginName: 'teacher01');
        };
        final container = _container(repository: repository);
        addTearDown(container.dispose);

        final controller = container.read(
          authSessionControllerProvider.notifier,
        );
        await pumpEventQueue();
        expect(
          container.read(authSessionControllerProvider).status,
          AuthSessionStatus.bootstrapFailure,
        );

        shouldFail = false;
        await controller.retryBootstrap();

        final state = container.read(authSessionControllerProvider);
        expect(state.status, AuthSessionStatus.authenticated);
        expect(state.user?.loginName, 'teacher01');
      },
    );
  });

  group('AuthSessionController signIn and signOut', () {
    test('signIn exposes only canonical authenticated session', () async {
      final repository = FakeAuthRepository();
      repository.onSignIn = (login, _) async => _user(loginName: login);
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authSessionControllerProvider.notifier);
      await pumpEventQueue();

      await controller.signIn(login: 'teacher01', password: 'secret');

      final state = container.read(authSessionControllerProvider);
      expect(state.status, AuthSessionStatus.authenticated);
      expect(state.user?.loginName, 'teacher01');
      expect(repository.signInCalls.single.password, 'secret');
      expect(state.toString(), isNot(contains('secret')));
    });

    test('signIn failure leaves unauthenticated state for retry', () async {
      final repository = FakeAuthRepository();
      var shouldFail = true;
      repository.onSignIn = (login, _) async {
        if (shouldFail) {
          throw _serverFailure(
            ApiErrorCodes.invalidCredentials,
            statusCode: 401,
          );
        }

        return _user(loginName: login);
      };
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authSessionControllerProvider.notifier);
      await pumpEventQueue();

      await controller.signIn(login: 'teacher01', password: 'wrong');
      expect(
        container.read(authSessionControllerProvider).status,
        AuthSessionStatus.unauthenticated,
      );
      expect(
        container.read(authSessionControllerProvider).failure?.serverCode,
        ApiErrorCodes.invalidCredentials,
      );

      shouldFail = false;
      await controller.signIn(login: 'teacher01', password: 'secret');

      expect(
        container.read(authSessionControllerProvider).status,
        AuthSessionStatus.authenticated,
      );
    });

    test(
      'me transport failure after login does not expose authenticated user',
      () async {
        final repository = FakeAuthRepository();
        repository.onSignIn = (_, _) async {
          throw _transportFailure();
        };
        final container = _container(repository: repository);
        addTearDown(container.dispose);
        final controller = container.read(
          authSessionControllerProvider.notifier,
        );
        await pumpEventQueue();

        await controller.signIn(login: 'teacher01', password: 'secret');

        final state = container.read(authSessionControllerProvider);
        expect(state.status, AuthSessionStatus.unauthenticated);
        expect(state.user, isNull);
        expect(state.failure?.kind, ApiFailureKind.connection);
      },
    );

    test(
      'signOut clears visible user even when backend logout fails',
      () async {
        final repository = FakeAuthRepository();
        repository.onSignIn = (login, _) async => _user(loginName: login);
        repository.onSignOut = () async {
          throw _transportFailure();
        };
        final container = _container(repository: repository);
        addTearDown(container.dispose);
        final controller = container.read(
          authSessionControllerProvider.notifier,
        );
        await pumpEventQueue();
        await controller.signIn(login: 'teacher01', password: 'secret');

        await controller.signOut();

        final state = container.read(authSessionControllerProvider);
        expect(state.status, AuthSessionStatus.unauthenticated);
        expect(state.user, isNull);
        expect(state.failure?.kind, ApiFailureKind.connection);
      },
    );

    test('no-token signOut safely clears state', () async {
      final repository = FakeAuthRepository();
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authSessionControllerProvider.notifier);
      await pumpEventQueue();

      await controller.signOut();

      expect(
        container.read(authSessionControllerProvider).status,
        AuthSessionStatus.unauthenticated,
      );
      expect(repository.signOutCalls, 1);
    });
  });

  group('AuthSessionController changePassword', () {
    test('successful change requires refreshed false server flag', () async {
      final repository = FakeAuthRepository(storedToken: 'token-a');
      repository.onCurrentUser = () async =>
          _user(loginName: 'teacher01', mustChangePassword: true);
      repository.onChangePassword = (_, _, _) async =>
          _user(loginName: 'teacher01');
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authSessionControllerProvider.notifier);
      await pumpEventQueue();
      expect(
        container.read(authSessionControllerProvider).user?.mustChangePassword,
        isTrue,
      );

      final result = await controller.changePassword(
        currentPassword: 'old-secret',
        newPassword: 'new-secret',
        newPasswordConfirmation: 'new-secret',
      );

      expect(result.isSuccess, isTrue);
      final state = container.read(authSessionControllerProvider);
      expect(state.status, AuthSessionStatus.authenticated);
      expect(state.user?.mustChangePassword, isFalse);
      expect(repository.changePasswordCalls, hasLength(1));
    });

    test('refreshed true flag remains gated with retryable failure', () async {
      final repository = FakeAuthRepository(storedToken: 'token-a');
      repository.onCurrentUser = () async =>
          _user(loginName: 'teacher01', mustChangePassword: true);
      repository.onChangePassword = (_, _, _) async =>
          _user(loginName: 'teacher01', mustChangePassword: true);
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authSessionControllerProvider.notifier);
      await pumpEventQueue();

      final result = await controller.changePassword(
        currentPassword: 'old-secret',
        newPassword: 'new-secret',
        newPasswordConfirmation: 'new-secret',
      );

      expect(result.isSuccess, isFalse);
      expect(result.canRetrySessionRefresh, isTrue);
      expect(result.failure?.kind, ApiFailureKind.invalidResponse);
      expect(
        container.read(authSessionControllerProvider).user?.mustChangePassword,
        isTrue,
      );
    });

    test(
      'current_password_invalid remains an authenticated form failure',
      () async {
        final repository = FakeAuthRepository(storedToken: 'token-a');
        repository.onCurrentUser = () async =>
            _user(loginName: 'teacher01', mustChangePassword: true);
        repository.onChangePassword = (_, _, _) async {
          throw _serverFailure(
            ApiErrorCodes.currentPasswordInvalid,
            statusCode: 409,
          );
        };
        final container = _container(repository: repository);
        addTearDown(container.dispose);
        final controller = container.read(
          authSessionControllerProvider.notifier,
        );
        await pumpEventQueue();

        final result = await controller.changePassword(
          currentPassword: 'wrong-secret',
          newPassword: 'new-secret',
          newPasswordConfirmation: 'new-secret',
        );

        expect(result.isSuccess, isFalse);
        expect(
          result.failure?.serverCode,
          ApiErrorCodes.currentPasswordInvalid,
        );
        expect(
          container.read(authSessionControllerProvider).status,
          AuthSessionStatus.authenticated,
        );
        expect(repository.storedToken, 'token-a');
      },
    );

    test('authentication_required during refresh clears the session', () async {
      final repository = FakeAuthRepository(storedToken: 'token-a');
      repository.onCurrentUser = () async =>
          _user(loginName: 'teacher01', mustChangePassword: true);
      repository.onChangePassword = (_, _, _) async {
        throw AuthPasswordChangeSessionRefreshException(
          _serverFailure(ApiErrorCodes.authenticationRequired, statusCode: 401),
        );
      };
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authSessionControllerProvider.notifier);
      await pumpEventQueue();

      final result = await controller.changePassword(
        currentPassword: 'old-secret',
        newPassword: 'new-secret',
        newPasswordConfirmation: 'new-secret',
      );

      expect(result.failure?.serverCode, ApiErrorCodes.authenticationRequired);
      expect(
        container.read(authSessionControllerProvider).status,
        AuthSessionStatus.unauthenticated,
      );
      expect(repository.storedToken, isNull);
    });

    test('retry session refresh does not resubmit password change', () async {
      final repository = FakeAuthRepository(storedToken: 'token-a');
      repository.onCurrentUser = () async =>
          _user(loginName: 'teacher01', mustChangePassword: true);
      repository.onChangePassword = (_, _, _) async {
        throw AuthPasswordChangeSessionRefreshException(_transportFailure());
      };
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authSessionControllerProvider.notifier);
      await pumpEventQueue();

      final first = await controller.changePassword(
        currentPassword: 'old-secret',
        newPassword: 'new-secret',
        newPasswordConfirmation: 'new-secret',
      );
      expect(first.canRetrySessionRefresh, isTrue);

      repository.onCurrentUser = () async => _user(loginName: 'teacher01');
      final retry = await controller.retryPasswordChangeSessionRefresh();

      expect(retry.isSuccess, isTrue);
      expect(repository.changePasswordCalls, hasLength(1));
      expect(repository.currentUserCalls, 2);
    });
  });

  group('AuthSessionController invalidation and races', () {
    test(
      'authentication_required signal clears active session without logout',
      () async {
        final signal = SessionInvalidationSignal();
        addTearDown(signal.dispose);
        final repository = FakeAuthRepository(
          storedToken: 'token-a',
          tokenVersion: 1,
        );
        repository.onSignIn = (login, _) async => _user(loginName: login);
        final container = _container(repository: repository, signal: signal);
        addTearDown(container.dispose);
        final controller = container.read(
          authSessionControllerProvider.notifier,
        );
        await pumpEventQueue();
        await controller.signIn(login: 'teacher01', password: 'secret');

        signal.authenticationRequired(tokenVersion: 1);
        await pumpEventQueue();

        final state = container.read(authSessionControllerProvider);
        expect(state.status, AuthSessionStatus.unauthenticated);
        expect(state.user, isNull);
        expect(repository.clearTokenIfVersionCalls, [1]);
        expect(repository.signOutCalls, 0);
      },
    );

    test(
      'stale invalidation signal does not corrupt newer active session',
      () async {
        final signal = SessionInvalidationSignal();
        addTearDown(signal.dispose);
        final repository = FakeAuthRepository(
          storedToken: 'token-b',
          tokenVersion: 2,
        );
        repository.onSignIn = (login, _) async => _user(loginName: login);
        final container = _container(repository: repository, signal: signal);
        addTearDown(container.dispose);
        final controller = container.read(
          authSessionControllerProvider.notifier,
        );
        await pumpEventQueue();
        await controller.signIn(login: 'user-b', password: 'secret-b');

        signal.authenticationRequired(tokenVersion: 1);
        await pumpEventQueue();

        final state = container.read(authSessionControllerProvider);
        expect(state.status, AuthSessionStatus.authenticated);
        expect(state.user?.loginName, 'user-b');
        expect(repository.storedToken, 'token-b');
      },
    );

    test('delayed bootstrap after logout cannot restore User A', () async {
      final repository = FakeAuthRepository(storedToken: 'token-a');
      final currentUser = Completer<AuthUser>();
      repository.onCurrentUser = () => currentUser.future;
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authSessionControllerProvider.notifier);
      await pumpEventQueue();

      await controller.signOut();
      currentUser.complete(_user(loginName: 'user-a'));
      await pumpEventQueue();

      final state = container.read(authSessionControllerProvider);
      expect(state.status, AuthSessionStatus.unauthenticated);
      expect(state.user, isNull);
    });

    test(
      'overlapping login keeps User B when delayed User A completes',
      () async {
        final repository = FakeAuthRepository();
        final signInA = Completer<AuthUser>();
        final signInB = Completer<AuthUser>();
        repository.onSignIn = (login, _) {
          return login == 'user-a' ? signInA.future : signInB.future;
        };
        final container = _container(repository: repository);
        addTearDown(container.dispose);
        final controller = container.read(
          authSessionControllerProvider.notifier,
        );
        await pumpEventQueue();

        final first = controller.signIn(login: 'user-a', password: 'secret-a');
        await pumpEventQueue();
        final second = controller.signIn(login: 'user-b', password: 'secret-b');
        signInB.complete(_user(loginName: 'user-b'));
        await second;

        signInA.complete(_user(loginName: 'user-a'));
        await first;
        await pumpEventQueue();

        final state = container.read(authSessionControllerProvider);
        expect(state.status, AuthSessionStatus.authenticated);
        expect(state.user?.loginName, 'user-b');
      },
    );

    test('logout supersedes delayed login result', () async {
      final repository = FakeAuthRepository();
      final signIn = Completer<AuthUser>();
      repository.onSignIn = (_, _) => signIn.future;
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authSessionControllerProvider.notifier);
      await pumpEventQueue();

      final signInFuture = controller.signIn(
        login: 'user-a',
        password: 'secret-a',
      );
      await pumpEventQueue();
      await controller.signOut();
      signIn.complete(_user(loginName: 'user-a'));
      await signInFuture;
      await pumpEventQueue();

      final state = container.read(authSessionControllerProvider);
      expect(state.status, AuthSessionStatus.unauthenticated);
      expect(state.user, isNull);
    });

    test('logout supersedes delayed password-change refresh result', () async {
      final repository = FakeAuthRepository(storedToken: 'token-a');
      final passwordChange = Completer<AuthUser>();
      repository.onCurrentUser = () async =>
          _user(loginName: 'user-a', mustChangePassword: true);
      repository.onChangePassword = (_, _, _) => passwordChange.future;
      final container = _container(repository: repository);
      addTearDown(container.dispose);
      final controller = container.read(authSessionControllerProvider.notifier);
      await pumpEventQueue();

      final changePassword = controller.changePassword(
        currentPassword: 'old-secret',
        newPassword: 'new-secret',
        newPasswordConfirmation: 'new-secret',
      );
      await pumpEventQueue();
      await controller.signOut();
      passwordChange.complete(_user(loginName: 'user-a'));
      await changePassword;
      await pumpEventQueue();

      final state = container.read(authSessionControllerProvider);
      expect(state.status, AuthSessionStatus.unauthenticated);
      expect(state.user, isNull);
    });
  });
}

ProviderContainer _container({
  required FakeAuthRepository repository,
  SessionInvalidationSignal? signal,
}) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      if (signal != null)
        sessionInvalidationSignalProvider.overrideWithValue(signal),
    ],
  );
}

AuthUser _user({
  required String loginName,
  UserRole role = UserRole.teacher,
  bool mustChangePassword = false,
}) {
  return AuthUser(
    id: '$loginName-id',
    institutionId: role == UserRole.platformOwner ? null : 'institution-1',
    role: role,
    fullName: 'Test User',
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
        message: 'Server rejected the request.',
        code: code,
        fieldErrors: const {},
        requestId: 'req-1',
      ),
    ),
  );
}

ApiRequestException _transportFailure() {
  return ApiRequestException(
    ApiFailure.local(
      kind: ApiFailureKind.connection,
      message: 'Connection failed.',
    ),
  );
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.storedToken, this.tokenVersion = 0});

  String? storedToken;
  int tokenVersion;

  Future<AuthUser> Function()? onCurrentUser;
  Future<AuthUser> Function(String login, String password)? onSignIn;
  Future<AuthUser> Function(
    String currentPassword,
    String newPassword,
    String newPasswordConfirmation,
  )?
  onChangePassword;
  Future<void> Function()? onSignOut;

  final signInCalls = <SignInCall>[];
  final changePasswordCalls = <ChangePasswordCall>[];
  final clearTokenIfVersionCalls = <int>[];
  var currentUserCalls = 0;
  var signOutCalls = 0;
  var clearTokenCalls = 0;

  @override
  Future<AuthUser> currentUser() {
    currentUserCalls += 1;

    return onCurrentUser?.call() ?? Future.value(_user(loginName: 'teacher01'));
  }

  @override
  Future<AuthUser> signIn({required String login, required String password}) {
    signInCalls.add(SignInCall(login: login, password: password));

    return onSignIn?.call(login, password) ??
        Future.value(_user(loginName: login));
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

    return onChangePassword?.call(
          currentPassword,
          newPassword,
          newPasswordConfirmation,
        ) ??
        Future.value(_user(loginName: 'teacher01'));
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

class SignInCall {
  const SignInCall({required this.login, required this.password});

  final String login;
  final String password;
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
