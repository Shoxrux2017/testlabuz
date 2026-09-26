import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_controller.dart';
import 'teacher_blitz_route_target.dart';
import 'teacher_session_key.dart';

final teacherBlitzRouteMutationActivityProvider = NotifierProvider.autoDispose
    .family<
      TeacherBlitzRouteMutationActivityController,
      TeacherBlitzRouteMutationActivityState,
      TeacherBlitzRouteTarget
    >(TeacherBlitzRouteMutationActivityController.new);

enum TeacherBlitzRouteMutationOperation {
  schedule,
  official,
  activate,
  close,
  archive,
}

/// Whether a Blitz lifecycle or official-designation mutation owns [target].
bool isTeacherBlitzRouteMutationActive(
  Ref ref,
  TeacherBlitzRouteTarget target,
) {
  final provider = teacherBlitzRouteMutationActivityProvider(target);
  return ref.exists(provider) && ref.read(provider).isActive;
}

class TeacherBlitzRouteMutationLease {
  const TeacherBlitzRouteMutationLease({
    required this.target,
    required this.sessionKey,
    required this.operation,
    required this.generation,
  });

  final TeacherBlitzRouteTarget target;
  final TeacherSessionKey sessionKey;
  final TeacherBlitzRouteMutationOperation operation;
  final int generation;
}

class TeacherBlitzRouteMutationActivityState {
  const TeacherBlitzRouteMutationActivityState({this.lease});

  final TeacherBlitzRouteMutationLease? lease;

  bool get isActive => lease != null;
}

class TeacherBlitzRouteMutationActivityController
    extends Notifier<TeacherBlitzRouteMutationActivityState> {
  TeacherBlitzRouteMutationActivityController(this.target);

  final TeacherBlitzRouteTarget target;
  TeacherSessionKey? _activeSessionKey;
  void Function()? _releaseRetention;
  var _generation = 0;
  var _initialized = false;

  @override
  TeacherBlitzRouteMutationActivityState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null) {
      _reset();
      _initialized = true;
      return const TeacherBlitzRouteMutationActivityState();
    }
    if (_initialized && _activeSessionKey == sessionKey) {
      return state;
    }

    _releaseRetentionNow();
    _generation += 1;
    _activeSessionKey = sessionKey;
    _initialized = true;
    return const TeacherBlitzRouteMutationActivityState();
  }

  TeacherBlitzRouteMutationLease? begin(
    TeacherBlitzRouteMutationOperation operation,
  ) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        state.isActive ||
        !_matchesSession(sessionKey) ||
        // Mobile may only activate; the other route mutations are desktop-only.
        (sessionKey.surface != AppDeviceSurface.desktop &&
            operation != TeacherBlitzRouteMutationOperation.activate)) {
      return null;
    }

    final lease = TeacherBlitzRouteMutationLease(
      target: target,
      sessionKey: sessionKey,
      operation: operation,
      generation: ++_generation,
    );
    _retainUntilSafe();
    state = TeacherBlitzRouteMutationActivityState(lease: lease);
    return lease;
  }

  bool owns(TeacherBlitzRouteMutationLease lease) {
    return ref.mounted &&
        identical(state.lease, lease) &&
        lease.target == target &&
        lease.generation == _generation &&
        _matchesSession(lease.sessionKey);
  }

  void release(TeacherBlitzRouteMutationLease lease) {
    if (!owns(lease)) {
      return;
    }
    _generation += 1;
    state = const TeacherBlitzRouteMutationActivityState();
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
    state = const TeacherBlitzRouteMutationActivityState();
    _releaseRetentionNow();
  }

  bool _matchesSession(TeacherSessionKey sessionKey) {
    return ref.mounted &&
        _activeSessionKey == sessionKey &&
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
