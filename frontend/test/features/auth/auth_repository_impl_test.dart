import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/network/api_error_codes.dart';
import 'package:testlabuz_client/core/network/api_error_response.dart';
import 'package:testlabuz_client/core/network/api_failure.dart';
import 'package:testlabuz_client/core/network/api_request_exception.dart';
import 'package:testlabuz_client/core/network/dio_failure_mapper.dart';
import 'package:testlabuz_client/core/storage/auth_token_store.dart';
import 'package:testlabuz_client/core/storage/secure_value_store.dart';
import 'package:testlabuz_client/features/auth/data/auth_remote_data_source.dart';
import 'package:testlabuz_client/features/auth/data/auth_repository_impl.dart';
import 'package:testlabuz_client/features/auth/data/dto/auth_login_response_dto.dart';
import 'package:testlabuz_client/features/auth/data/dto/auth_me_response_dto.dart';
import 'package:testlabuz_client/features/auth/data/dto/auth_user_dto.dart';
import 'package:testlabuz_client/features/auth/domain/auth_repository.dart';
import 'package:testlabuz_client/features/auth/domain/user_role.dart';

void main() {
  group('AuthRepositoryImpl', () {
    test('signIn stores token and returns canonical /auth/me user', () async {
      final remote = FakeAuthRemoteDataSource();
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStore: tokenStore,
      );
      remote.onLogin = (_, _) async =>
          _loginResponse(token: 'token-a', loginRole: UserRole.teacher);
      remote.onMe = () async => _meResponse(role: UserRole.student);

      final user = await repository.signIn(
        login: 'student01',
        password: 'secret',
      );

      expect(await tokenStore.read(), 'token-a');
      expect(user.role, UserRole.student);
      expect(user.loginName, 'student01');
      expect(remote.loginCalls.single.login, 'student01');
      expect(remote.loginCalls.single.password, 'secret');
    });

    test('invalid credentials leaves token absent', () async {
      final remote = FakeAuthRemoteDataSource();
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStore: tokenStore,
      );
      remote.onLogin = (_, _) async {
        throw _serverFailure(ApiErrorCodes.invalidCredentials, statusCode: 401);
      };

      await expectLater(
        repository.signIn(login: 'teacher01', password: 'wrong'),
        throwsA(
          isA<ApiRequestException>().having(
            (exception) => exception.failure.serverCode,
            'serverCode',
            ApiErrorCodes.invalidCredentials,
          ),
        ),
      );

      expect(await tokenStore.read(), isNull);
      expect(remote.meCalls, 0);
    });

    test(
      'account-state rejection after token issuance clears new token',
      () async {
        final remote = FakeAuthRemoteDataSource();
        final tokenStore = AuthTokenStore(FakeSecureValueStore());
        final repository = AuthRepositoryImpl(
          remoteDataSource: remote,
          tokenStore: tokenStore,
        );
        remote.onLogin = (_, _) async => _loginResponse(token: 'token-a');
        remote.onMe = () async {
          throw _serverFailure(ApiErrorCodes.userInactive, statusCode: 403);
        };

        await expectLater(
          repository.signIn(login: 'teacher01', password: 'secret'),
          throwsA(isA<ApiRequestException>()),
        );

        expect(await tokenStore.read(), isNull);
      },
    );

    test(
      'transport failure after token issuance keeps token without user',
      () async {
        final remote = FakeAuthRemoteDataSource();
        final tokenStore = AuthTokenStore(FakeSecureValueStore());
        final repository = AuthRepositoryImpl(
          remoteDataSource: remote,
          tokenStore: tokenStore,
        );
        remote.onLogin = (_, _) async => _loginResponse(token: 'token-a');
        remote.onMe = () async {
          throw _transportFailure();
        };

        await expectLater(
          repository.signIn(login: 'teacher01', password: 'secret'),
          throwsA(
            isA<ApiRequestException>().having(
              (exception) => exception.failure.kind,
              'kind',
              ApiFailureKind.connection,
            ),
          ),
        );

        expect(await tokenStore.read(), 'token-a');
      },
    );

    test('currentUser returns /auth/me domain user', () async {
      final remote = FakeAuthRemoteDataSource();
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStore: AuthTokenStore(FakeSecureValueStore()),
      );
      remote.onMe = () async => _meResponse(role: UserRole.parent);

      final user = await repository.currentUser();

      expect(user.role, UserRole.parent);
    });

    test(
      'changePassword refreshes and returns canonical /auth/me user',
      () async {
        final remote = FakeAuthRemoteDataSource();
        final tokenStore = AuthTokenStore(FakeSecureValueStore());
        await tokenStore.write('token-a');
        final repository = AuthRepositoryImpl(
          remoteDataSource: remote,
          tokenStore: tokenStore,
        );
        remote.onMe = () async => _meResponse(role: UserRole.student);

        final user = await repository.changePassword(
          currentPassword: 'old-secret',
          newPassword: 'new-secret',
          newPasswordConfirmation: 'new-secret',
        );

        expect(user.role, UserRole.student);
        expect(remote.changePasswordCalls.single.currentPassword, 'old-secret');
        expect(remote.changePasswordCalls.single.newPassword, 'new-secret');
        expect(
          remote.changePasswordCalls.single.newPasswordConfirmation,
          'new-secret',
        );
        expect(remote.meCalls, 1);
        expect(await tokenStore.read(), 'token-a');
      },
    );

    test('changePassword surfaces current password conflict', () async {
      final remote = FakeAuthRemoteDataSource();
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStore: AuthTokenStore(FakeSecureValueStore()),
      );
      remote.onChangePassword = (_, _, _) async {
        throw _serverFailure(
          ApiErrorCodes.currentPasswordInvalid,
          statusCode: 409,
        );
      };

      await expectLater(
        repository.changePassword(
          currentPassword: 'wrong-secret',
          newPassword: 'new-secret',
          newPasswordConfirmation: 'new-secret',
        ),
        throwsA(
          isA<ApiRequestException>().having(
            (exception) => exception.failure.serverCode,
            'serverCode',
            ApiErrorCodes.currentPasswordInvalid,
          ),
        ),
      );

      expect(remote.meCalls, 0);
    });

    test(
      'transport failure after password mutation keeps token for refresh retry',
      () async {
        final remote = FakeAuthRemoteDataSource();
        final tokenStore = AuthTokenStore(FakeSecureValueStore());
        await tokenStore.write('token-a');
        final repository = AuthRepositoryImpl(
          remoteDataSource: remote,
          tokenStore: tokenStore,
        );
        remote.onMe = () async {
          throw _transportFailure();
        };

        await expectLater(
          repository.changePassword(
            currentPassword: 'old-secret',
            newPassword: 'new-secret',
            newPasswordConfirmation: 'new-secret',
          ),
          throwsA(
            isA<AuthPasswordChangeSessionRefreshException>().having(
              (exception) => exception.cause.failure.kind,
              'kind',
              ApiFailureKind.connection,
            ),
          ),
        );

        expect(remote.changePasswordCalls, hasLength(1));
        expect(remote.meCalls, 1);
        expect(await tokenStore.read(), 'token-a');
      },
    );

    test('signOut calls backend logout and clears token', () async {
      final remote = FakeAuthRemoteDataSource();
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStore: tokenStore,
      );
      await tokenStore.write('token-a');

      await repository.signOut();

      expect(remote.logoutCalls, 1);
      expect(await tokenStore.read(), isNull);
    });

    test('signOut clears token even when backend logout fails', () async {
      final remote = FakeAuthRemoteDataSource();
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStore: tokenStore,
      );
      await tokenStore.write('token-a');
      remote.onLogout = () async {
        throw _transportFailure();
      };

      await expectLater(
        repository.signOut(),
        throwsA(isA<ApiRequestException>()),
      );

      expect(remote.logoutCalls, 1);
      expect(await tokenStore.read(), isNull);
    });

    test('signOut without token does not call backend logout', () async {
      final remote = FakeAuthRemoteDataSource();
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStore: AuthTokenStore(FakeSecureValueStore()),
      );

      await repository.signOut();

      expect(remote.logoutCalls, 0);
    });

    test(
      'overlapping login cannot let delayed User A overwrite User B token',
      () async {
        final remote = FakeAuthRemoteDataSource();
        final tokenStore = AuthTokenStore(FakeSecureValueStore());
        final repository = AuthRepositoryImpl(
          remoteDataSource: remote,
          tokenStore: tokenStore,
        );
        final loginA = Completer<AuthLoginResponseDto>();
        final loginB = Completer<AuthLoginResponseDto>();
        final meB = Completer<AuthMeResponseDto>();
        remote.onLogin = (login, _) {
          return login == 'user-a' ? loginA.future : loginB.future;
        };
        remote.onMe = () => meB.future;

        final signInA = repository.signIn(
          login: 'user-a',
          password: 'secret-a',
        );
        final signInB = repository.signIn(
          login: 'user-b',
          password: 'secret-b',
        );

        loginB.complete(_loginResponse(token: 'token-b'));
        meB.complete(_meResponse(loginName: 'user-b'));
        final userB = await signInB;

        loginA.complete(_loginResponse(token: 'token-a'));

        expect(userB.loginName, 'user-b');
        await expectLater(
          signInA,
          throwsA(isA<AuthOperationSupersededException>()),
        );
        expect(await tokenStore.read(), 'token-b');
      },
    );

    test('logout supersedes delayed login before token persistence', () async {
      final remote = FakeAuthRemoteDataSource();
      final tokenStore = AuthTokenStore(FakeSecureValueStore());
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        tokenStore: tokenStore,
      );
      final login = Completer<AuthLoginResponseDto>();
      remote.onLogin = (_, _) => login.future;

      final signIn = repository.signIn(login: 'user-a', password: 'secret-a');
      await repository.signOut();
      login.complete(_loginResponse(token: 'token-a'));

      await expectLater(
        signIn,
        throwsA(isA<AuthOperationSupersededException>()),
      );
      expect(await tokenStore.read(), isNull);
    });
  });
}

AuthLoginResponseDto _loginResponse({
  required String token,
  UserRole loginRole = UserRole.teacher,
}) {
  return AuthLoginResponseDto(
    token: token,
    tokenType: 'Bearer',
    user: _userDto(role: loginRole, loginName: 'login-payload-user'),
  );
}

AuthMeResponseDto _meResponse({
  UserRole role = UserRole.teacher,
  String loginName = 'student01',
}) {
  return AuthMeResponseDto(
    user: _userDto(role: role, loginName: loginName),
  );
}

AuthUserDto _userDto({required UserRole role, required String loginName}) {
  final institutionId = role == UserRole.platformOwner ? null : 'institution-1';

  return AuthUserDto(
    id: '$loginName-id',
    institutionId: institutionId,
    role: role,
    fullName: 'Test User',
    loginName: loginName,
    email: null,
    phone: null,
    isActive: true,
    mustChangePassword: false,
    institution: null,
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

class FakeAuthRemoteDataSource extends AuthRemoteDataSource {
  FakeAuthRemoteDataSource()
    : super(dio: Dio(), failureMapper: const DioFailureMapper());

  Future<AuthLoginResponseDto> Function(String login, String password)? onLogin;
  Future<void> Function(
    String currentPassword,
    String newPassword,
    String newPasswordConfirmation,
  )?
  onChangePassword;
  Future<AuthMeResponseDto> Function()? onMe;
  Future<void> Function()? onLogout;

  final loginCalls = <LoginCall>[];
  final changePasswordCalls = <ChangePasswordCall>[];
  var meCalls = 0;
  var logoutCalls = 0;

  @override
  Future<AuthLoginResponseDto> login({
    required String login,
    required String password,
  }) {
    loginCalls.add(LoginCall(login: login, password: password));

    return onLogin?.call(login, password) ??
        Future.value(_loginResponse(token: 'token-a'));
  }

  @override
  Future<void> changePassword({
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
        Future.value();
  }

  @override
  Future<AuthMeResponseDto> me() {
    meCalls += 1;

    return onMe?.call() ?? Future.value(_meResponse());
  }

  @override
  Future<void> logout() {
    logoutCalls += 1;

    return onLogout?.call() ?? Future.value();
  }
}

class LoginCall {
  const LoginCall({required this.login, required this.password});

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

class FakeSecureValueStore implements SecureValueStore {
  final values = <String, String>{};

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return values[key];
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}
