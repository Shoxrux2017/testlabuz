import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_controller.dart';
import 'teacher_homework_route_target.dart';
import 'teacher_session_key.dart';

final teacherHomeworkRouteMutationActivityProvider = NotifierProvider
    .autoDispose
    .family<
      TeacherHomeworkRouteMutationActivityController,
      TeacherHomeworkRouteMutationActivityState,
      TeacherHomeworkRouteTarget
    >(TeacherHomeworkRouteMutationActivityController.new);

enum TeacherHomeworkRouteMutationOperation { lifecycle, official }

class TeacherHomeworkRouteMutationLease {
  const TeacherHomeworkRouteMutationLease({
    required this.target,
    required this.sessionKey,
    required this.operation,
    required this.generation,
  });

  final TeacherHomeworkRouteTarget target;
  final TeacherSessionKey sessionKey;
  final TeacherHomeworkRouteMutationOperation operation;
  final int generation;
}

class TeacherHomeworkRouteMutationActivityState {
  const TeacherHomeworkRouteMutationActivityState({
    this.lease,
    this.outcomeReviewBlocking = false,
  });

  final TeacherHomeworkRouteMutationLease? lease;
  final bool outcomeReviewBlocking;

  bool get isActive => lease != null;
}

class TeacherHomeworkRouteMutationActivityController
    extends Notifier<TeacherHomeworkRouteMutationActivityState> {
  TeacherHomeworkRouteMutationActivityController(this.target);

  final TeacherHomeworkRouteTarget target;
  TeacherSessionKey? _activeSessionKey;
  void Function()? _releaseRetention;
  var _generation = 0;
  var _initialized = false;

  @override
  TeacherHomeworkRouteMutationActivityState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null || sessionKey.surface != AppDeviceSurface.desktop) {
      _reset();
      _initialized = true;
      return const TeacherHomeworkRouteMutationActivityState();
    }
    if (_initialized && _activeSessionKey == sessionKey) {
      return state;
    }

    _releaseRetentionNow();
    _generation += 1;
    _activeSessionKey = sessionKey;
    _initialized = true;
    return const TeacherHomeworkRouteMutationActivityState();
  }

  TeacherHomeworkRouteMutationLease? begin(
    TeacherHomeworkRouteMutationOperation operation,
  ) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null || state.isActive || !_matchesSession(sessionKey)) {
      return null;
    }

    final lease = TeacherHomeworkRouteMutationLease(
      target: target,
      sessionKey: sessionKey,
      operation: operation,
      generation: ++_generation,
    );
    _retainUntilSafe();
    state = TeacherHomeworkRouteMutationActivityState(lease: lease);
    return lease;
  }

  bool owns(TeacherHomeworkRouteMutationLease lease) {
    return ref.mounted &&
        identical(state.lease, lease) &&
        lease.target == target &&
        lease.generation == _generation &&
        _matchesSession(lease.sessionKey);
  }

  void markOutcomeReviewBlocking(TeacherHomeworkRouteMutationLease lease) {
    if (!owns(lease)) {
      return;
    }
    state = TeacherHomeworkRouteMutationActivityState(
      lease: lease,
      outcomeReviewBlocking: true,
    );
  }

  void release(TeacherHomeworkRouteMutationLease lease) {
    if (!owns(lease)) {
      return;
    }
    _generation += 1;
    state = const TeacherHomeworkRouteMutationActivityState();
    _releaseRetentionNow();
  }

  /// Ends this route target even when the operation controller that acquired
  /// the lease has already been disposed.
  void endRoute() {
    _generation += 1;
    if (!ref.mounted) {
      _releaseRetentionNow();
      return;
    }
    state = const TeacherHomeworkRouteMutationActivityState();
    _releaseRetentionNow();
  }

  bool _matchesSession(TeacherSessionKey sessionKey) {
    return ref.mounted &&
        _activeSessionKey == sessionKey &&
        sessionKey.surface == AppDeviceSurface.desktop &&
        TeacherSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            sessionKey;
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

  void _releaseRetentionNow() {
    final release = _releaseRetention;
    _releaseRetention = null;
    release?.call();
  }
}
