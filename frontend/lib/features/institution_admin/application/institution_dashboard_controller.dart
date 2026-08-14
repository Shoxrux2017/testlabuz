import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/user_role.dart';
import '../data/institution_dashboard_repository_impl.dart';
import 'institution_dashboard_state.dart';

final institutionDashboardControllerProvider =
    NotifierProvider.autoDispose<
      InstitutionDashboardController,
      InstitutionDashboardState
    >(InstitutionDashboardController.new);

class InstitutionDashboardController
    extends Notifier<InstitutionDashboardState> {
  String? _sessionUserId;
  String? _sessionInstitutionId;
  int _operationGeneration = 0;
  int? _inFlightGeneration;
  var _isDisposed = false;

  @override
  InstitutionDashboardState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _invalidateOperations();
    });

    final sessionKey = ref.watch(
      authSessionControllerProvider.select(
        _InstitutionDashboardSessionKey.fromSession,
      ),
    );
    if (!sessionKey.isEligible) {
      _sessionUserId = null;
      _sessionInstitutionId = null;
      _invalidateOperations();

      return const InstitutionDashboardState.initial();
    }

    final userId = sessionKey.userId!;
    final institutionId = sessionKey.userInstitutionId!;
    if (_sessionUserId == userId && _sessionInstitutionId == institutionId) {
      return state;
    }

    _invalidateOperations();
    _sessionUserId = userId;
    _sessionInstitutionId = institutionId;
    scheduleMicrotask(() {
      if (_matchesCurrentSession(userId, institutionId)) {
        unawaited(
          _loadForSession(
            sessionUserId: userId,
            sessionInstitutionId: institutionId,
          ),
        );
      }
    });

    return const InstitutionDashboardState.loading();
  }

  Future<void> refresh() async {
    if (state.status != InstitutionDashboardStatus.data ||
        _inFlightGeneration != null) {
      return;
    }

    final identity = _currentIdentity();
    if (identity == null) {
      return;
    }

    state = const InstitutionDashboardState.loading();
    await _loadForSession(
      sessionUserId: identity.userId,
      sessionInstitutionId: identity.institutionId,
    );
  }

  Future<void> retry() async {
    if (state.status != InstitutionDashboardStatus.error ||
        state.isRetryInFlight ||
        _inFlightGeneration != null) {
      return;
    }

    final identity = _currentIdentity();
    if (identity == null) {
      return;
    }

    state = state.retrying();
    await _loadForSession(
      sessionUserId: identity.userId,
      sessionInstitutionId: identity.institutionId,
    );
  }

  Future<void> _loadForSession({
    required String sessionUserId,
    required String sessionInstitutionId,
  }) async {
    if (_inFlightGeneration != null ||
        !_matchesCurrentSession(sessionUserId, sessionInstitutionId)) {
      return;
    }

    final generation = _beginOperation();

    try {
      final repository = ref.read(institutionDashboardRepositoryProvider);
      final dashboard = await repository.fetchDashboard();
      if (!_canComplete(generation, sessionUserId, sessionInstitutionId)) {
        return;
      }

      state = InstitutionDashboardState.data(dashboard);
    } on ApiRequestException catch (exception) {
      if (!_canComplete(generation, sessionUserId, sessionInstitutionId)) {
        return;
      }

      _reconcileSessionForFailure(exception.failure);
      state = InstitutionDashboardState.error(exception.failure);
    } catch (_) {
      if (!_canComplete(generation, sessionUserId, sessionInstitutionId)) {
        return;
      }

      state = InstitutionDashboardState.error(
        ApiFailure.local(
          kind: ApiFailureKind.unknown,
          message: 'Unexpected institution dashboard failure.',
        ),
      );
    } finally {
      if (_inFlightGeneration == generation) {
        _inFlightGeneration = null;
      }
    }
  }

  int _beginOperation() {
    _operationGeneration += 1;
    _inFlightGeneration = _operationGeneration;

    return _operationGeneration;
  }

  void _invalidateOperations() {
    _operationGeneration += 1;
    _inFlightGeneration = null;
  }

  bool _canComplete(
    int generation,
    String sessionUserId,
    String sessionInstitutionId,
  ) {
    if (_isDisposed ||
        generation != _operationGeneration ||
        generation != _inFlightGeneration ||
        !_matchesCurrentSession(sessionUserId, sessionInstitutionId)) {
      return false;
    }

    final session = ref.read(authSessionControllerProvider);
    final sessionKey = _InstitutionDashboardSessionKey.fromSession(session);

    return sessionKey.isEligible &&
        sessionKey.userId == sessionUserId &&
        sessionKey.userInstitutionId == sessionInstitutionId;
  }

  bool _matchesCurrentSession(String userId, String institutionId) {
    return !_isDisposed &&
        _sessionUserId == userId &&
        _sessionInstitutionId == institutionId;
  }

  _InstitutionDashboardIdentity? _currentIdentity() {
    final userId = _sessionUserId;
    final institutionId = _sessionInstitutionId;
    if (userId == null || institutionId == null) {
      return null;
    }

    final session = ref.read(authSessionControllerProvider);
    final sessionKey = _InstitutionDashboardSessionKey.fromSession(session);
    if (!sessionKey.isEligible ||
        sessionKey.userId != userId ||
        sessionKey.userInstitutionId != institutionId) {
      return null;
    }

    return _InstitutionDashboardIdentity(
      userId: userId,
      institutionId: institutionId,
    );
  }

  void _reconcileSessionForFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code == ApiErrorCodes.passwordChangeRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
  }
}

class _InstitutionDashboardSessionKey {
  const _InstitutionDashboardSessionKey({
    required this.status,
    required this.userId,
    required this.userInstitutionId,
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
    required this.institutionId,
    required this.institutionStatus,
  });

  factory _InstitutionDashboardSessionKey.fromSession(
    AuthSessionState session,
  ) {
    final user = session.user;
    final institution = user?.institution;

    return _InstitutionDashboardSessionKey(
      status: session.status,
      userId: user?.id,
      userInstitutionId: user?.institutionId,
      role: user?.role,
      isActive: user?.isActive,
      mustChangePassword: user?.mustChangePassword,
      institutionId: institution?.id,
      institutionStatus: institution?.status,
    );
  }

  final AuthSessionStatus status;
  final String? userId;
  final String? userInstitutionId;
  final UserRole? role;
  final bool? isActive;
  final bool? mustChangePassword;
  final String? institutionId;
  final String? institutionStatus;

  bool get isEligible {
    final currentInstitutionId = userInstitutionId;

    return status == AuthSessionStatus.authenticated &&
        userId != null &&
        role == UserRole.institutionAdmin &&
        isActive == true &&
        mustChangePassword == false &&
        currentInstitutionId != null &&
        currentInstitutionId.trim().isNotEmpty &&
        institutionId == currentInstitutionId &&
        institutionStatus == 'active';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _InstitutionDashboardSessionKey &&
            other.status == status &&
            other.userId == userId &&
            other.userInstitutionId == userInstitutionId &&
            other.role == role &&
            other.isActive == isActive &&
            other.mustChangePassword == mustChangePassword &&
            other.institutionId == institutionId &&
            other.institutionStatus == institutionStatus;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      userId,
      userInstitutionId,
      role,
      isActive,
      mustChangePassword,
      institutionId,
      institutionStatus,
    );
  }
}

class _InstitutionDashboardIdentity {
  const _InstitutionDashboardIdentity({
    required this.userId,
    required this.institutionId,
  });

  final String userId;
  final String institutionId;
}
