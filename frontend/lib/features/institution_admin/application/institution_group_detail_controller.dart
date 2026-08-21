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
import '../data/dto/institution_group_dto.dart';
import '../data/institution_group_detail_repository_impl.dart';
import 'institution_group_detail_state.dart';

final institutionGroupDetailControllerProvider = NotifierProvider.autoDispose
    .family<
      InstitutionGroupDetailController,
      InstitutionGroupDetailState,
      String
    >(InstitutionGroupDetailController.new);

class InstitutionGroupDetailController
    extends Notifier<InstitutionGroupDetailState> {
  InstitutionGroupDetailController(this.groupId);

  final String groupId;

  InstitutionGroupDetailSessionKey? _activeSessionKey;
  String? _activeTarget;
  String? _inFlightTarget;
  int _operationGeneration = 0;

  @override
  InstitutionGroupDetailState build() {
    final sessionKey = InstitutionGroupDetailSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;

    if (!isCanonicalInstitutionGroupId(groupId)) {
      _clearActiveSession();
      return const InstitutionGroupDetailState.localUnavailableTarget();
    }

    if (sessionKey == null) {
      _clearActiveSession();
      return InstitutionGroupDetailState.initial(target: groupId);
    }

    if (_activeSessionKey == sessionKey && _activeTarget == groupId) {
      return state;
    }

    _invalidateOperations();
    _activeSessionKey = sessionKey;
    _activeTarget = groupId;
    scheduleMicrotask(() {
      if (_matchesSession(sessionKey) && _activeTarget == groupId) {
        _startLoad(
          groupId,
          sessionKey: sessionKey,
          presentation: _DetailLoadPresentation.initial,
        );
      }
    });

    return InstitutionGroupDetailState.loading(target: groupId);
  }

  void refresh() {
    final sessionKey = _activeSessionKey;
    final target = _activeTarget;
    final currentGroup = state.group;
    if (sessionKey == null ||
        target == null ||
        currentGroup == null ||
        state.status != InstitutionGroupDetailStatus.data ||
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
        state.status != InstitutionGroupDetailStatus.error ||
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

  void _startLoad(
    String target, {
    required InstitutionGroupDetailSessionKey sessionKey,
    required _DetailLoadPresentation presentation,
  }) {
    if (!_matchesSession(sessionKey) ||
        _activeTarget != target ||
        _inFlightTarget == target) {
      return;
    }

    final generation = ++_operationGeneration;
    _inFlightTarget = target;
    final currentGroup = state.group;
    state = switch (presentation) {
      _DetailLoadPresentation.initial || _DetailLoadPresentation.retry =>
        InstitutionGroupDetailState.loading(target: target),
      _DetailLoadPresentation.refresh when currentGroup != null =>
        InstitutionGroupDetailState.refreshing(
          target: target,
          group: currentGroup,
        ),
      _DetailLoadPresentation.refresh => InstitutionGroupDetailState.loading(
        target: target,
      ),
    };

    unawaited(_load(target, sessionKey: sessionKey, generation: generation));
  }

  Future<void> _load(
    String target, {
    required InstitutionGroupDetailSessionKey sessionKey,
    required int generation,
  }) async {
    try {
      final group = await ref
          .read(institutionGroupDetailRepositoryProvider)
          .fetchGroup(target);
      if (!_canPublish(generation, sessionKey, target)) {
        return;
      }

      state = InstitutionGroupDetailState.data(target: target, group: group);
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
          message: 'Unexpected Institution Group detail failure.',
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
      state = InstitutionGroupDetailState.notFound(target: target);
      return;
    }

    if (_isSessionFailure(failure)) {
      _clearActiveSession();
      state = const InstitutionGroupDetailState.initial();
      if (code != ApiErrorCodes.authenticationRequired) {
        unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
      }
      return;
    }

    state = InstitutionGroupDetailState.error(
      target: target,
      failure: failure,
      isRetryable: _isRetryable(failure),
    );
  }

  bool _canPublish(
    int generation,
    InstitutionGroupDetailSessionKey sessionKey,
    String target,
  ) {
    return ref.mounted &&
        generation == _operationGeneration &&
        _inFlightTarget == target &&
        _activeTarget == target &&
        _activeSessionKey == sessionKey &&
        _matchesSession(sessionKey);
  }

  bool _matchesSession(InstitutionGroupDetailSessionKey key) {
    return ref.mounted &&
        _activeSessionKey == key &&
        InstitutionGroupDetailSessionSnapshot.fromSession(
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

class InstitutionGroupDetailSessionSnapshot {
  const InstitutionGroupDetailSessionSnapshot({
    required this.status,
    required this.user,
    required this.surface,
  });

  factory InstitutionGroupDetailSessionSnapshot.fromSession(
    AuthSessionState session,
    AppDeviceSurface surface,
  ) {
    return InstitutionGroupDetailSessionSnapshot(
      status: session.status,
      user: session.user,
      surface: surface,
    );
  }

  final AuthSessionStatus status;
  final AuthUser? user;
  final AppDeviceSurface surface;

  InstitutionGroupDetailSessionKey? get eligibleKey {
    final currentUser = user;
    final institutionId = currentUser?.institutionId;
    final institution = currentUser?.institution;
    if (status != AuthSessionStatus.authenticated ||
        currentUser == null ||
        currentUser.id.isEmpty ||
        currentUser.role != UserRole.institutionAdmin ||
        !currentUser.isActive ||
        currentUser.mustChangePassword ||
        institutionId == null ||
        institutionId.trim().isEmpty ||
        institution == null ||
        institution.id != institutionId ||
        institution.status != 'active' ||
        surface != AppDeviceSurface.desktop) {
      return null;
    }

    return InstitutionGroupDetailSessionKey(
      userId: currentUser.id,
      userInstance: currentUser,
      institutionId: institutionId,
    );
  }
}

class InstitutionGroupDetailSessionKey {
  const InstitutionGroupDetailSessionKey({
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
        other is InstitutionGroupDetailSessionKey &&
            other.userId == userId &&
            identical(other.userInstance, userInstance) &&
            other.institutionId == institutionId;
  }

  @override
  int get hashCode =>
      Object.hash(userId, identityHashCode(userInstance), institutionId);
}

enum _DetailLoadPresentation { initial, refresh, retry }
