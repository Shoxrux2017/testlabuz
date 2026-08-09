import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/session_invalidation_signal.dart';
import '../data/auth_repository_impl.dart';
import '../domain/auth_repository.dart';
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
}
