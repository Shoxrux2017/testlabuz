import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_controller.dart';
import '../domain/teacher_question_mutation.dart';
import 'teacher_homework_route_target.dart';
import 'teacher_session_key.dart';

final teacherQuestionMutationActivityProvider = NotifierProvider.autoDispose
    .family<
      TeacherQuestionMutationActivityController,
      TeacherQuestionMutationActivityState,
      TeacherHomeworkRouteTarget
    >(TeacherQuestionMutationActivityController.new);

class TeacherQuestionMutationLease {
  const TeacherQuestionMutationLease({
    required this.target,
    required this.sessionKey,
    required this.operation,
    required this.generation,
  });

  final TeacherHomeworkRouteTarget target;
  final TeacherSessionKey sessionKey;
  final TeacherQuestionMutationOperation operation;
  final int generation;
}

class TeacherQuestionMutationActivityState {
  const TeacherQuestionMutationActivityState({
    this.lease,
    this.outcomeReviewBlocking = false,
    this.authoritativeReloadRequired = false,
  });

  final TeacherQuestionMutationLease? lease;
  final bool outcomeReviewBlocking;
  final bool authoritativeReloadRequired;

  bool get isActive => lease != null;
}

class TeacherQuestionMutationActivityController
    extends Notifier<TeacherQuestionMutationActivityState> {
  TeacherQuestionMutationActivityController(this.target);

  final TeacherHomeworkRouteTarget target;
  TeacherSessionKey? _activeSessionKey;
  void Function()? _releaseRetention;
  var _generation = 0;
  var _initialized = false;

  @override
  TeacherQuestionMutationActivityState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null || sessionKey.surface != AppDeviceSurface.desktop) {
      _reset();
      _initialized = true;
      return const TeacherQuestionMutationActivityState();
    }
    if (_initialized && _activeSessionKey == sessionKey) {
      return state;
    }

    _releaseRetentionNow();
    _generation += 1;
    _activeSessionKey = sessionKey;
    _initialized = true;
    return const TeacherQuestionMutationActivityState();
  }

  TeacherQuestionMutationLease? begin(
    TeacherQuestionMutationOperation operation,
  ) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        state.isActive ||
        state.authoritativeReloadRequired ||
        !_matchesSession(sessionKey)) {
      return null;
    }

    final lease = TeacherQuestionMutationLease(
      target: target,
      sessionKey: sessionKey,
      operation: operation,
      generation: ++_generation,
    );
    _retainUntilSafe();
    state = TeacherQuestionMutationActivityState(lease: lease);
    return lease;
  }

  bool owns(TeacherQuestionMutationLease lease) {
    return ref.mounted &&
        identical(state.lease, lease) &&
        lease.target == target &&
        lease.generation == _generation &&
        _matchesSession(lease.sessionKey);
  }

  void markOutcomeReviewBlocking(TeacherQuestionMutationLease lease) {
    if (!owns(lease)) {
      return;
    }
    state = TeacherQuestionMutationActivityState(
      lease: lease,
      outcomeReviewBlocking: true,
      authoritativeReloadRequired: state.authoritativeReloadRequired,
    );
  }

  void requireAuthoritativeReload([TeacherQuestionMutationLease? lease]) {
    if (!ref.mounted ||
        (lease != null && !owns(lease)) ||
        state.authoritativeReloadRequired) {
      return;
    }
    _retainUntilSafe();
    state = TeacherQuestionMutationActivityState(
      lease: state.lease,
      outcomeReviewBlocking: state.outcomeReviewBlocking,
      authoritativeReloadRequired: true,
    );
  }

  void release(TeacherQuestionMutationLease lease) {
    if (!owns(lease)) {
      return;
    }
    _generation += 1;
    state = TeacherQuestionMutationActivityState(
      authoritativeReloadRequired: state.authoritativeReloadRequired,
    );
    _releaseRetentionIfSafe();
  }

  void resolveAuthoritativeReload() {
    if (!ref.mounted || state.isActive || !state.authoritativeReloadRequired) {
      return;
    }
    state = const TeacherQuestionMutationActivityState();
    _releaseRetentionIfSafe();
  }

  bool _matchesSession(TeacherSessionKey sessionKey) {
    return ref.mounted &&
        _activeSessionKey == sessionKey &&
        TeacherSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            sessionKey &&
        sessionKey.surface == AppDeviceSurface.desktop;
  }

  void _reset() {
    _generation += 1;
    _activeSessionKey = null;
    _releaseRetentionNow();
  }

  void _retainUntilSafe() {
    if (_releaseRetention != null) {
      return;
    }
    final link = ref.keepAlive();
    _releaseRetention = link.close;
  }

  void _releaseRetentionIfSafe() {
    if (state.isActive || state.authoritativeReloadRequired) {
      return;
    }
    _releaseRetentionNow();
  }

  void _releaseRetentionNow() {
    final release = _releaseRetention;
    _releaseRetention = null;
    release?.call();
  }
}
