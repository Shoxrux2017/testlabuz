import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/storage/auth_token_store.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'auth_remote_data_source.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    tokenStore: ref.watch(authTokenStoreProvider),
  );
});

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.tokenStore,
  });

  final AuthRemoteDataSource remoteDataSource;
  final AuthTokenStore tokenStore;
  int _operationEpoch = 0;

  @override
  Future<AuthUser> signIn({
    required String login,
    required String password,
  }) async {
    final epoch = _beginAuthOperation();
    final loginResponse = await remoteDataSource.login(
      login: login,
      password: password,
    );

    _throwIfSuperseded(epoch);
    await tokenStore.write(loginResponse.token);
    final storedTokenVersion = tokenStore.version;

    try {
      final currentUser = await remoteDataSource.me();
      _throwIfSuperseded(epoch);

      return currentUser.user.toDomain();
    } on ApiRequestException catch (exception) {
      if (_shouldClearNewLoginToken(exception)) {
        await tokenStore.deleteIfVersion(storedTokenVersion);
      }

      rethrow;
    }
  }

  @override
  Future<AuthUser> currentUser() async {
    final currentUser = await remoteDataSource.me();

    return currentUser.user.toDomain();
  }

  @override
  Future<void> signOut() async {
    _beginAuthOperation();
    final snapshot = await tokenStore.readSnapshot();
    ApiRequestException? logoutFailure;

    if (snapshot.token != null) {
      try {
        await remoteDataSource.logout();
      } on ApiRequestException catch (exception) {
        logoutFailure = exception;
      }
    }

    await tokenStore.deleteIfVersion(snapshot.version);

    if (logoutFailure != null) {
      throw logoutFailure;
    }
  }

  @override
  Future<String?> readStoredToken() {
    return tokenStore.read();
  }

  @override
  Future<void> clearToken() {
    _beginAuthOperation();

    return tokenStore.delete();
  }

  @override
  Future<bool> clearTokenIfVersion(int tokenVersion) {
    _beginAuthOperation();

    return tokenStore.deleteIfVersion(tokenVersion);
  }

  int _beginAuthOperation() {
    _operationEpoch += 1;

    return _operationEpoch;
  }

  void _throwIfSuperseded(int epoch) {
    if (epoch != _operationEpoch) {
      throw const AuthOperationSupersededException();
    }
  }

  bool _shouldClearNewLoginToken(ApiRequestException exception) {
    final code = exception.failure.serverCode;

    return code == ApiErrorCodes.authenticationRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive;
  }
}
