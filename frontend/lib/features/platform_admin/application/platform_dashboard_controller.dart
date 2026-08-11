import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/user_role.dart';
import '../data/platform_dashboard_repository_impl.dart';
import 'platform_dashboard_state.dart';

final platformDashboardControllerProvider =
    NotifierProvider.autoDispose<
      PlatformDashboardController,
      PlatformDashboardState
    >(PlatformDashboardController.new);

class PlatformDashboardController extends Notifier<PlatformDashboardState> {
  String? _sessionUserId;
  int _operationGeneration = 0;
  var _isDisposed = false;

  @override
  PlatformDashboardState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _operationGeneration += 1;
    });

    final session = ref.watch(authSessionControllerProvider);
    final user = session.user;

    if (session.status != AuthSessionStatus.authenticated ||
        user == null ||
        user.role != UserRole.platformOwner ||
        user.mustChangePassword) {
      _sessionUserId = null;
      _operationGeneration += 1;

      return const PlatformDashboardState.initial();
    }

    if (_sessionUserId == user.id) {
      return state;
    }

    _sessionUserId = user.id;
    scheduleMicrotask(() {
      if (!_isDisposed && _sessionUserId == user.id) {
        unawaited(_loadForSession(user.id));
      }
    });

    return const PlatformDashboardState.loading();
  }

  Future<void> retry() async {
    if (state.status != PlatformDashboardStatus.error ||
        state.isRetryInFlight) {
      return;
    }

    final sessionUserId = _sessionUserId;
    if (sessionUserId == null) {
      return;
    }

    state = state.retrying();
    await _loadForSession(sessionUserId);
  }

  Future<void> _loadForSession(String sessionUserId) async {
    final generation = _beginOperation();
    final repository = ref.read(platformDashboardRepositoryProvider);

    try {
      final dashboard = await repository.fetchDashboard();
      if (!_canComplete(generation, sessionUserId)) {
        return;
      }

      state = PlatformDashboardState.data(dashboard);
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation, sessionUserId)) {
        return;
      }

      _reconcileSessionForFailure(exception.failure);
      state = PlatformDashboardState.error(exception.failure);
    }
  }

  int _beginOperation() {
    _operationGeneration += 1;

    return _operationGeneration;
  }

  bool _canComplete(int generation, String sessionUserId) {
    return !_isDisposed &&
        generation == _operationGeneration &&
        sessionUserId == _sessionUserId;
  }

  void _reconcileSessionForFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code == ApiErrorCodes.authenticationRequired ||
        code == ApiErrorCodes.passwordChangeRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
  }
}
