import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/domain/user_role.dart';
import '../data/institution_user_detail_repository_impl.dart';
import '../data/dto/institution_user_dto.dart';
import 'institution_user_detail_state.dart';

final institutionUserDetailControllerProvider = NotifierProvider.autoDispose
    .family<
      InstitutionUserDetailController,
      InstitutionUserDetailState,
      String
    >(InstitutionUserDetailController.new);

class InstitutionUserDetailController
    extends Notifier<InstitutionUserDetailState> {
  InstitutionUserDetailController(this.userId);

  final String userId;

  InstitutionUserDetailSessionKey? _activeSessionKey;
  String? _activeTarget;
  String? _inFlightTarget;
  int _operationGeneration = 0;
  var _isDisposed = false;
  var _disposeRegistered = false;

  @override
  InstitutionUserDetailState build() {
    _isDisposed = false;
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      ref.onDispose(() {
        _isDisposed = true;
        _invalidateOperations();
      });
    }

    final session = ref.watch(authSessionControllerProvider);
    final surface = ref.watch(appDeviceSurfaceProvider);
    final sessionKey = InstitutionUserDetailSessionSnapshot.fromSession(
      session,
      surface,
    ).eligibleKey;

    if (!isCanonicalInstitutionUserId(userId)) {
      _clearActiveSession();

      return const InstitutionUserDetailState.localUnavailableTarget();
    }

    if (sessionKey == null) {
      _clearActiveSession();

      return InstitutionUserDetailState.initial(target: userId);
    }

    if (_activeSessionKey == sessionKey && _activeTarget == userId) {
      return state;
    }

    _invalidateOperations();
    _activeSessionKey = sessionKey;
    _activeTarget = userId;
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey) && _activeTarget == userId) {
        _startLoad(
          userId,
          sessionKey: sessionKey,
          presentation: _DetailLoadPresentation.initial,
        );
      }
    });

    return InstitutionUserDetailState.loading(target: userId);
  }

  void refresh() {
    final sessionKey = _activeSessionKey;
    final target = _activeTarget;
    final currentUser = state.user;
    if (sessionKey == null ||
        target == null ||
        currentUser == null ||
        state.status != InstitutionUserDetailStatus.data ||
        _inFlightTarget != null) {
      return;
    }

    _startLoad(
      target,
      sessionKey: sessionKey,
      presentation: _DetailLoadPresentation.refresh,
    );
  }

  void retry() {
    final sessionKey = _activeSessionKey;
    final target = _activeTarget;
    if (sessionKey == null ||
        target == null ||
        state.status != InstitutionUserDetailStatus.error ||
        !state.isRetryable ||
        _inFlightTarget != null) {
      return;
    }

    _startLoad(
      target,
      sessionKey: sessionKey,
      presentation: _DetailLoadPresentation.retry,
    );
  }

  void clearForRouteExit() {
    _clearActiveSession();
    state = const InstitutionUserDetailState.initial();
  }

  void _startLoad(
    String target, {
    required InstitutionUserDetailSessionKey sessionKey,
    required _DetailLoadPresentation presentation,
  }) {
    if (!_matchesSession(sessionKey) ||
        _activeTarget != target ||
        _inFlightTarget == target) {
      return;
    }

    final generation = ++_operationGeneration;
    _inFlightTarget = target;
    final currentUser = state.user;
    state = switch (presentation) {
      _DetailLoadPresentation.initial || _DetailLoadPresentation.retry =>
        InstitutionUserDetailState.loading(target: target),
      _DetailLoadPresentation.refresh when currentUser != null =>
        InstitutionUserDetailState.refreshing(
          target: target,
          user: currentUser,
        ),
      _DetailLoadPresentation.refresh => InstitutionUserDetailState.loading(
        target: target,
      ),
    };

    unawaited(_load(target, sessionKey: sessionKey, generation: generation));
  }

  Future<void> _load(
    String target, {
    required InstitutionUserDetailSessionKey sessionKey,
    required int generation,
  }) async {
    try {
      final user = await ref
          .read(institutionUserDetailRepositoryProvider)
          .fetchUser(target);
      if (!_canPublish(generation, sessionKey, target)) {
        return;
      }

      state = InstitutionUserDetailState.data(target: target, user: user);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey, target)) {
        return;
      }
      _publishFailure(target, exception.failure);
    } catch (_) {
      if (!_canPublish(generation, sessionKey, target)) {
        return;
      }
      _publishFailure(
        target,
        ApiFailure.local(
          kind: ApiFailureKind.unknown,
          message: 'Unexpected Institution User detail failure.',
        ),
      );
    } finally {
      if (generation == _operationGeneration && _inFlightTarget == target) {
        _inFlightTarget = null;
      }
    }
  }

  void _publishFailure(String target, ApiFailure failure) {
    final code = failure.serverCode;
    if (failure.statusCode == 404 && code == ApiErrorCodes.resourceNotFound) {
      state = InstitutionUserDetailState.notFound(target: target);
      return;
    }

    if (_isSessionFailure(failure)) {
      _clearActiveSession();
      state = const InstitutionUserDetailState.initial();
      if (code != ApiErrorCodes.authenticationRequired) {
        unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
      }
      return;
    }

    state = InstitutionUserDetailState.error(
      target: target,
      failure: failure,
      isRetryable: _isRetryable(failure),
    );
  }

  bool _canPublish(
    int generation,
    InstitutionUserDetailSessionKey sessionKey,
    String target,
  ) {
    return !_isDisposed &&
        generation == _operationGeneration &&
        _inFlightTarget == target &&
        _activeTarget == target &&
        _activeSessionKey == sessionKey &&
        _matchesSession(sessionKey);
  }

  bool _matchesSession(InstitutionUserDetailSessionKey key) {
    return !_isDisposed &&
        _activeSessionKey == key &&
        InstitutionUserDetailSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            key;
  }

  bool _isSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;

    return failure.statusCode == 401 ||
        code == ApiErrorCodes.authenticationRequired ||
        code == ApiErrorCodes.passwordChangeRequired ||
        code == ApiErrorCodes.userInactive ||
        code == ApiErrorCodes.institutionInactive;
  }

  bool _isRetryable(ApiFailure failure) {
    return failure.kind == ApiFailureKind.connection ||
        failure.kind == ApiFailureKind.timeout ||
        failure.kind == ApiFailureKind.unknown ||
        (failure.kind == ApiFailureKind.server &&
            (failure.statusCode ?? 0) >= 500);
  }

  void _clearActiveSession() {
    _activeSessionKey = null;
    _activeTarget = null;
    _invalidateOperations();
  }

  void _invalidateOperations() {
    _operationGeneration += 1;
    _inFlightTarget = null;
  }
}

class InstitutionUserDetailSessionSnapshot {
  const InstitutionUserDetailSessionSnapshot({
    required this.status,
    required this.userId,
    required this.userInstance,
    required this.userInstitutionId,
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
    required this.institutionId,
    required this.institutionStatus,
    required this.surface,
  });

  factory InstitutionUserDetailSessionSnapshot.fromSession(
    AuthSessionState session,
    AppDeviceSurface surface,
  ) {
    final user = session.user;
    final institution = user?.institution;

    return InstitutionUserDetailSessionSnapshot(
      status: session.status,
      userId: user?.id,
      userInstance: user,
      userInstitutionId: user?.institutionId,
      role: user?.role,
      isActive: user?.isActive,
      mustChangePassword: user?.mustChangePassword,
      institutionId: institution?.id,
      institutionStatus: institution?.status,
      surface: surface,
    );
  }

  final AuthSessionStatus status;
  final String? userId;
  final AuthUser? userInstance;
  final String? userInstitutionId;
  final UserRole? role;
  final bool? isActive;
  final bool? mustChangePassword;
  final String? institutionId;
  final String? institutionStatus;
  final AppDeviceSurface surface;

  InstitutionUserDetailSessionKey? get eligibleKey {
    final currentUserId = userId;
    final currentInstitutionId = userInstitutionId;
    if (status != AuthSessionStatus.authenticated ||
        currentUserId == null ||
        currentUserId.isEmpty ||
        userInstance == null ||
        role != UserRole.institutionAdmin ||
        isActive != true ||
        mustChangePassword != false ||
        currentInstitutionId == null ||
        currentInstitutionId.trim().isEmpty ||
        institutionId != currentInstitutionId ||
        institutionStatus != 'active' ||
        surface != AppDeviceSurface.desktop) {
      return null;
    }

    return InstitutionUserDetailSessionKey(
      userId: currentUserId,
      userInstance: userInstance!,
      institutionId: currentInstitutionId,
    );
  }
}

class InstitutionUserDetailSessionKey {
  const InstitutionUserDetailSessionKey({
    required this.userId,
    required this.userInstance,
    required this.institutionId,
  });

  final String userId;
  final AuthUser userInstance;
  final String institutionId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstitutionUserDetailSessionKey &&
            other.userId == userId &&
            identical(other.userInstance, userInstance) &&
            other.institutionId == institutionId;
  }

  @override
  int get hashCode =>
      Object.hash(userId, identityHashCode(userInstance), institutionId);
}

enum _DetailLoadPresentation { initial, refresh, retry }
