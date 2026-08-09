import '../../../core/network/api_failure.dart';
import '../domain/auth_user.dart';

enum AuthSessionStatus {
  initial,
  bootstrapping,
  unauthenticated,
  authenticating,
  authenticated,
  bootstrapFailure,
}

class AuthSessionState {
  const AuthSessionState._({
    required this.status,
    required this.user,
    required this.failure,
  });

  const AuthSessionState.initial()
    : this._(status: AuthSessionStatus.initial, user: null, failure: null);

  const AuthSessionState.bootstrapping()
    : this._(
        status: AuthSessionStatus.bootstrapping,
        user: null,
        failure: null,
      );

  const AuthSessionState.unauthenticated({ApiFailure? failure})
    : this._(
        status: AuthSessionStatus.unauthenticated,
        user: null,
        failure: failure,
      );

  const AuthSessionState.authenticating()
    : this._(
        status: AuthSessionStatus.authenticating,
        user: null,
        failure: null,
      );

  const AuthSessionState.authenticated(AuthUser user)
    : this._(
        status: AuthSessionStatus.authenticated,
        user: user,
        failure: null,
      );

  const AuthSessionState.bootstrapFailure(ApiFailure failure)
    : this._(
        status: AuthSessionStatus.bootstrapFailure,
        user: null,
        failure: failure,
      );

  final AuthSessionStatus status;
  final AuthUser? user;
  final ApiFailure? failure;

  bool get isAuthenticated => status == AuthSessionStatus.authenticated;
}
