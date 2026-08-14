import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/session_invalidation_signal.dart';
import '../data/auth_repository_impl.dart';
import '../domain/auth_institution.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import '../domain/user_role.dart';
import 'auth_password_change_result.dart';
import 'auth_session_state.dart';

final authSessionControllerProvider =
    NotifierProvider<AuthSessionController, AuthSessionState>(
      AuthSessionController.new,
    );

class AuthSessionController extends Notifier<AuthSessionState> {
  StreamSubscription<SessionInvalidationEvent>?
  _sessionInvalidationSubscription;
  int _generation = 0;

  @override
  AuthSessionState build() {
    final signal = ref.watch(sessionInvalidationSignalProvider);
    final repository = ref.watch(authRepositoryProvider);

    _sessionInvalidationSubscription?.cancel();
    _sessionInvalidationSubscription = signal.stream.listen(
      (event) => unawaited(_handleSessionInvalidation(event, repository)),
    );
    ref.onDispose(() => _sessionInvalidationSubscription?.cancel());

    unawaited(bootstrap());

    return const AuthSessionState.initial();
  }

  Future<void> bootstrap() async {
    final generation = _advanceGeneration();
    final repository = ref.read(authRepositoryProvider);

    state = const AuthSessionState.bootstrapping();

    final token = await repository.readStoredToken();
    if (!_isCurrentGeneration(generation)) {
      return;
    }

    if (token == null) {
      state = const AuthSessionState.unauthenticated();
      return;
    }

    try {
      final user = await repository.currentUser();
      if (!_isCurrentGeneration(generation)) {
        return;
      }

      state = AuthSessionState.authenticated(user);
    } on ApiRequestException catch (exception) {
      if (!_isCurrentGeneration(generation)) {
        return;
      }

      if (_requiresLocalSessionClear(exception)) {
        await repository.clearToken();
        if (!_isCurrentGeneration(generation)) {
          return;
        }

        state = AuthSessionState.unauthenticated(failure: exception.failure);
        return;
      }

      state = AuthSessionState.bootstrapFailure(exception.failure);
    }
  }

  Future<void> retryBootstrap() {
    return bootstrap();
  }

  Future<void> signIn({required String login, required String password}) async {
    final generation = _advanceGeneration();
    final repository = ref.read(authRepositoryProvider);

    state = const AuthSessionState.authenticating();

    try {
      final user = await repository.signIn(login: login, password: password);
      if (!_isCurrentGeneration(generation)) {
        return;
      }

      state = AuthSessionState.authenticated(user);
    } on AuthOperationSupersededException {
      return;
    } on ApiRequestException catch (exception) {
      if (!_isCurrentGeneration(generation)) {
        return;
      }

      state = AuthSessionState.unauthenticated(failure: exception.failure);
    }
  }

  Future<AuthPasswordChangeResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final generation = _advanceGeneration();
    final repository = ref.read(authRepositoryProvider);

    try {
      final user = await repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirmation: newPasswordConfirmation,
      );
      if (!_isCurrentGeneration(generation)) {
        return const AuthPasswordChangeResult.superseded();
      }

      return _completePasswordChangeWithRefreshedUser(user);
    } on AuthPasswordChangeSessionRefreshException catch (exception) {
      if (!_isCurrentGeneration(generation)) {
        return const AuthPasswordChangeResult.superseded();
      }

      return _handlePasswordChangeRefreshFailure(
        exception.cause,
        generation,
        canRetrySessionRefresh: _isRetryableSessionRefreshFailure(
          exception.cause.failure,
        ),
      );
    } on ApiRequestException catch (exception) {
      if (!_isCurrentGeneration(generation)) {
        return const AuthPasswordChangeResult.superseded();
      }

      return _handlePasswordChangeRefreshFailure(
        exception,
        generation,
        canRetrySessionRefresh: false,
      );
    }
  }

  Future<AuthPasswordChangeResult> retryPasswordChangeSessionRefresh() {
    final generation = _advanceGeneration();

    return _refreshAfterPasswordChange(generation);
  }

  Future<void> signOut() async {
    final generation = _advanceGeneration();
    final repository = ref.read(authRepositoryProvider);

    state = const AuthSessionState.unauthenticated();

    try {
      await repository.signOut();
      if (!_isCurrentGeneration(generation)) {
        return;
      }

      state = const AuthSessionState.unauthenticated();
    } on ApiRequestException catch (exception) {
      if (!_isCurrentGeneration(generation)) {
        return;
      }

      state = AuthSessionState.unauthenticated(failure: exception.failure);
    }
  }

  bool reconcileInstitutionNameFromServer({
    required String expectedUserId,
    required String expectedInstitutionId,
    required String institutionName,
  }) {
    final user = state.user;
    final institution = user?.institution;
    if (state.status != AuthSessionStatus.authenticated ||
        user == null ||
        user.id != expectedUserId ||
        user.role != UserRole.institutionAdmin ||
        !user.isActive ||
        user.mustChangePassword ||
        user.institutionId == null ||
        user.institutionId!.trim().isEmpty ||
        user.institutionId != expectedInstitutionId ||
        institution == null ||
        institution.id != expectedInstitutionId ||
        institution.status != 'active') {
      return false;
    }

    if (institution.name == institutionName) {
      return true;
    }

    final reconciledInstitution = AuthInstitution(
      id: institution.id,
      name: institutionName,
      status: institution.status,
      timezone: institution.timezone,
    );
    state = AuthSessionState.authenticated(
      AuthUser(
        id: user.id,
        institutionId: user.institutionId,
        role: user.role,
        fullName: user.fullName,
        loginName: user.loginName,
        email: user.email,
        phone: user.phone,
        isActive: user.isActive,
        mustChangePassword: user.mustChangePassword,
        institution: reconciledInstitution,
      ),
    );

    return true;
  }

  Future<AuthPasswordChangeResult> _refreshAfterPasswordChange(
    int generation,
  ) async {
    final repository = ref.read(authRepositoryProvider);

    try {
      final user = await repository.currentUser();
      if (!_isCurrentGeneration(generation)) {
        return const AuthPasswordChangeResult.superseded();
      }

      if (user.mustChangePassword) {
        return _passwordStillRequiredFailure();
      }

      return _completePasswordChangeWithRefreshedUser(user);
    } on ApiRequestException catch (exception) {
      if (!_isCurrentGeneration(generation)) {
        return const AuthPasswordChangeResult.superseded();
      }

      return _handlePasswordChangeRefreshFailure(
        exception,
        generation,
        canRetrySessionRefresh: _isRetryableSessionRefreshFailure(
          exception.failure,
        ),
      );
    }
  }

  AuthPasswordChangeResult _completePasswordChangeWithRefreshedUser(
    AuthUser user,
  ) {
    if (user.mustChangePassword) {
      return _passwordStillRequiredFailure();
    }

    state = AuthSessionState.authenticated(user);

    return const AuthPasswordChangeResult.success();
  }

  AuthPasswordChangeResult _passwordStillRequiredFailure() {
    return AuthPasswordChangeResult.failure(
      ApiFailure.local(
        kind: ApiFailureKind.invalidResponse,
        message: 'Password change is still required by the server.',
      ),
      canRetrySessionRefresh: true,
    );
  }

  Future<AuthPasswordChangeResult> _handlePasswordChangeRefreshFailure(
    ApiRequestException exception,
    int generation, {
    required bool canRetrySessionRefresh,
  }) async {
    final repository = ref.read(authRepositoryProvider);

    if (_requiresLocalSessionClear(exception)) {
      await repository.clearToken();
      if (!_isCurrentGeneration(generation)) {
        return const AuthPasswordChangeResult.superseded();
      }

      state = AuthSessionState.unauthenticated(failure: exception.failure);
    }

    return AuthPasswordChangeResult.failure(
      exception.failure,
      canRetrySessionRefresh: canRetrySessionRefresh,
    );
  }

  Future<void> _handleSessionInvalidation(
    SessionInvalidationEvent event,
    AuthRepository repository,
  ) async {
    if (event.reason != SessionInvalidationReason.authenticationRequired) {
      return;
    }

    if (state.status != AuthSessionStatus.authenticated) {
      return;
    }

    final cleared = await repository.clearTokenIfVersion(event.tokenVersion);
    if (!cleared || state.status != AuthSessionStatus.authenticated) {
      return;
    }

    _advanceGeneration();
    state = const AuthSessionState.unauthenticated();
  }

  int _advanceGeneration() {
    _generation += 1;

    return _generation;
  }

  bool _isCurrentGeneration(int generation) {
    return generation == _generation;
  }

  bool _requiresLocalSessionClear(ApiRequestException exception) {
    final code = exception.failure.serverCode;

    return code == ApiErrorCodes.authenticationRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive;
  }

  bool _isRetryableSessionRefreshFailure(ApiFailure failure) {
    return failure.kind == ApiFailureKind.connection ||
        failure.kind == ApiFailureKind.timeout ||
        failure.kind == ApiFailureKind.invalidResponse ||
        failure.kind == ApiFailureKind.unknown;
  }
}
