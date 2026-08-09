import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_request_exception.dart';
import 'auth_user.dart';

abstract interface class AuthRepository {
  Future<AuthUser> signIn({required String login, required String password});

  Future<AuthUser> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  });

  Future<AuthUser> currentUser();

  Future<void> signOut();

  Future<String?> readStoredToken();

  Future<void> clearToken();

  Future<bool> clearTokenIfVersion(int tokenVersion);
}

class AuthOperationSupersededException implements Exception {
  const AuthOperationSupersededException();

  @override
  String toString() => 'AuthOperationSupersededException';
}

class AuthPasswordChangeSessionRefreshException implements Exception {
  const AuthPasswordChangeSessionRefreshException(this.cause);

  final ApiRequestException cause;

  @override
  String toString() => 'AuthPasswordChangeSessionRefreshException';
}

bool isAuthOrAccountStateRejection(ApiRequestException exception) {
  final code = exception.failure.serverCode;

  return code == ApiErrorCodes.authenticationRequired ||
      code == ApiErrorCodes.userInactive ||
      code == ApiErrorCodes.institutionInactive;
}
