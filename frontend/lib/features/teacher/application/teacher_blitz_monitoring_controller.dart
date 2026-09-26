import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_blitz_repository_impl.dart';
import '../domain/teacher_blitz_monitoring.dart';
import 'teacher_blitz_detail_controller.dart';
import 'teacher_blitz_monitoring_state.dart';
import 'teacher_blitz_parent_identity.dart';
import 'teacher_blitz_route_target.dart';
import 'teacher_session_key.dart';

final teacherBlitzMonitoringControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherBlitzMonitoringController,
      TeacherBlitzMonitoringState,
      TeacherBlitzRouteTarget
    >(TeacherBlitzMonitoringController.new);

const teacherBlitzMonitoringPollInterval = Duration(seconds: 5);

/// Live monitoring of one Active Blitz, polled by one controller timer while
/// the route owns the screen in the foreground.
class TeacherBlitzMonitoringController
    extends Notifier<TeacherBlitzMonitoringState> {
  TeacherBlitzMonitoringController(this.target);

  final TeacherBlitzRouteTarget target;
  TeacherSessionKey? _sessionKey;
  TeacherBlitzParentIdentity? _identity;
  Timer? _pollTimer;
  TeacherBlitzMonitoringState? _stateBeforeRead;
  var _requestActive = false;
  var _generation = 0;
  var _routeEpoch = 0;
  var _routeOwned = false;
  var _routeLeft = false;
  var _appResumed = true;
  var _dialogHold = false;
  var _grantOwnsRoute = false;
  var _ownershipSyncScheduled = false;
  var _disposed = false;

  /// Changes whenever route, session or parent-identity ownership changes, so
  /// a grant dialog opened under an older ownership never sends.
  int get routeEpoch => _routeEpoch;

  @override
  TeacherBlitzMonitoringState build() {
    _disposed = false;
    ref.onDispose(_dispose);
    // Listened to, not watched: a rebuild would drop the poll timer, so every
    // ownership change is reconciled explicitly instead.
    ref
      ..listen(
        authSessionControllerProvider,
        (_, _) => _scheduleOwnershipSync(),
      )
      ..listen(appDeviceSurfaceProvider, (_, _) => _scheduleOwnershipSync())
      ..listen(
        teacherBlitzDetailControllerProvider(
          target,
        ).select((detail) => teacherBlitzParentIdentity(detail, target)),
        (_, _) => _scheduleOwnershipSync(),
      );

    _sessionKey = _currentSessionKey();
    _identity = _sessionKey == null ? null : _currentIdentity();
    _scheduleInitialRead();
    return _stateForOwnership();
  }

  /// The monitoring route is now the current foreground owner.
  void enterLiveRoute() {
    if (!_isAlive) {
      return;
    }
    _routeOwned = true;
    _routeLeft = false;
    _publish(state);
  }

  /// Stops polling and drops every later publication for this route.
  void leaveLiveRoute() {
    _routeOwned = false;
    _routeLeft = true;
    _routeEpoch += 1;
    _stopPolling();
    if (!_isAlive) {
      _cancelRead();
      return;
    }
    if (_requestActive) {
      _abandonActiveRead();
    } else {
      _publish(state);
    }
  }

  void setAppResumed(bool resumed) {
    if (!_isAlive || resumed == _appResumed) {
      return;
    }
    _appResumed = resumed;
    _publish(state);
    if (resumed) {
      _readAfterPause();
    }
  }

  /// Pauses polling so a candidate row cannot change under an open dialog.
  void holdForDialog() {
    if (!_isAlive) {
      return;
    }
    _dialogHold = true;
    _publish(state);
  }

  void releaseDialogHold() {
    if (!_isAlive || !_dialogHold) {
      return;
    }
    _dialogHold = false;
    _publish(state);
    _readAfterPause();
  }

  /// Manual Refresh or Retry; also the only way out of a rate-limit pause.
  void refresh() {
    if (!_isAlive || _requestActive || _grantOwnsRoute || state.hasEnded) {
      return;
    }
    unawaited(_startRead(automatic: false));
  }

  /// Called by the grant controller: while a grant owns the route, polling
  /// and manual Refresh pause.
  void setGrantOwnership(bool owns) {
    if (!_isAlive || owns == _grantOwnsRoute) {
      return;
    }
    _grantOwnsRoute = owns;
    // A read started before the grant could publish a pre-grant row after it.
    if (owns && _requestActive) {
      _abandonActiveRead();
    } else {
      _publish(state);
    }
  }

  /// One reconciliation read for the grant that owns the route. Returns the
  /// published state, or null when this route can no longer publish.
  Future<TeacherBlitzMonitoringState?> readForGrant() {
    if (!_isAlive || state.hasEnded) {
      return Future.value();
    }
    if (_requestActive) {
      _abandonActiveRead();
    }
    return _startRead(automatic: false);
  }

  bool get _isAlive => !_disposed && ref.mounted;

  /// Deferred so the Blitz detail has seen the same session change before the
  /// parent identity is re-read; otherwise an older session's detail could
  /// confirm the new session.
  void _scheduleOwnershipSync() {
    if (_ownershipSyncScheduled) {
      return;
    }
    _ownershipSyncScheduled = true;
    scheduleMicrotask(() {
      _ownershipSyncScheduled = false;
      _syncOwnership();
    });
  }

  void _syncOwnership() {
    if (!_isAlive) {
      return;
    }
    final sessionKey = _currentSessionKey();
    final identity = sessionKey == null ? null : _currentIdentity();
    if (sessionKey == _sessionKey && identity == _identity) {
      return;
    }
    _resetOwnership();
    _sessionKey = sessionKey;
    _identity = identity;
    _publish(_stateForOwnership());
    _scheduleInitialRead();
  }

  TeacherBlitzMonitoringState _stateForOwnership() {
    if (_sessionKey == null) {
      return const TeacherBlitzMonitoringState();
    }
    return switch (_identity) {
      TeacherBlitzParentIdentity.checking ||
      TeacherBlitzParentIdentity.confirmed => const TeacherBlitzMonitoringState(
        status: TeacherBlitzMonitoringStatus.loading,
      ),
      TeacherBlitzParentIdentity.notFound => const TeacherBlitzMonitoringState(
        status: TeacherBlitzMonitoringStatus.notFound,
      ),
      // No independent monitoring fallback while the parent is unconfirmed.
      TeacherBlitzParentIdentity.error ||
      null => const TeacherBlitzMonitoringState(),
    };
  }

  void _scheduleInitialRead() {
    if (_identity != TeacherBlitzParentIdentity.confirmed) {
      return;
    }
    final epoch = _routeEpoch;
    scheduleMicrotask(() {
      if (_isAlive && epoch == _routeEpoch && !_requestActive) {
        unawaited(_startRead(automatic: false));
      }
    });
  }

  void _readAfterPause() {
    if (_shouldPoll(state) && !_requestActive) {
      unawaited(_startRead(automatic: true));
    }
  }

  void _onPollTick() {
    if (_isAlive && !_requestActive) {
      unawaited(_startRead(automatic: true));
    }
  }

  Future<TeacherBlitzMonitoringState?> _startRead({required bool automatic}) {
    final sessionKey = _sessionKey;
    if (_routeLeft ||
        sessionKey == null ||
        _identity != TeacherBlitzParentIdentity.confirmed ||
        !_matchesSession(sessionKey)) {
      return Future.value();
    }
    final generation = ++_generation;
    _requestActive = true;
    _stateBeforeRead = state;
    final retained = state.monitoring;
    _publish(
      TeacherBlitzMonitoringState(
        status: retained == null
            ? TeacherBlitzMonitoringStatus.loading
            : TeacherBlitzMonitoringStatus.refreshing,
        monitoring: retained,
        isStale: state.isStale,
        pollingPausedByRateLimit: state.pollingPausedByRateLimit,
        lastRefreshWasAutomatic: automatic,
      ),
    );
    return _read(sessionKey, generation, retained);
  }

  Future<TeacherBlitzMonitoringState?> _read(
    TeacherSessionKey sessionKey,
    int generation,
    TeacherBlitzMonitoring? retained,
  ) async {
    final repository = ref.read(teacherBlitzRepositoryProvider);
    try {
      final monitoring = await repository.fetchMonitoring(target.blitzId);
      if (!_canPublish(generation, sessionKey)) {
        return null;
      }
      if (monitoring.blitz.id.toLowerCase() != target.blitzId.toLowerCase()) {
        return _finishWithFailure(
          retained,
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            message: 'Teacher Blitz monitoring does not match the route.',
          ),
        );
      }
      return _finishRead(
        TeacherBlitzMonitoringState(
          status: TeacherBlitzMonitoringStatus.data,
          monitoring: monitoring,
          lastRefreshWasAutomatic: state.lastRefreshWasAutomatic,
        ),
      );
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, sessionKey)) {
        return null;
      }
      final failure = exception.failure;
      if (_isSessionFailure(failure)) {
        _clearForSessionFailure(failure);
        return null;
      }
      final ended = _endedStatus(failure);
      if (ended != null) {
        return _finishRead(
          TeacherBlitzMonitoringState(status: ended, failure: failure),
        );
      }
      return _finishWithFailure(retained, failure);
    } catch (_) {
      if (!_canPublish(generation, sessionKey)) {
        return null;
      }
      return _finishWithFailure(
        retained,
        ApiFailure.local(
          kind: ApiFailureKind.unknown,
          message: 'Unexpected Teacher Blitz monitoring failure.',
        ),
      );
    } finally {
      if (generation == _generation) {
        _requestActive = false;
      }
    }
  }

  TeacherBlitzMonitoringState _finishWithFailure(
    TeacherBlitzMonitoring? retained,
    ApiFailure failure,
  ) {
    return _finishRead(
      TeacherBlitzMonitoringState(
        status: TeacherBlitzMonitoringStatus.error,
        monitoring: retained,
        failure: failure,
        isStale: retained != null,
        pollingPausedByRateLimit:
            failure.statusCode == 429 &&
            failure.serverCode == ApiErrorCodes.rateLimited,
        lastRefreshWasAutomatic: state.lastRefreshWasAutomatic,
      ),
    );
  }

  TeacherBlitzMonitoringState _finishRead(TeacherBlitzMonitoringState next) {
    _requestActive = false;
    _stateBeforeRead = null;
    _publish(next);
    return state;
  }

  /// Publishes [next] and starts or stops the single poll timer to match it.
  void _publish(TeacherBlitzMonitoringState next) {
    final poll = _shouldPoll(next);
    if (poll) {
      _pollTimer ??= Timer.periodic(
        teacherBlitzMonitoringPollInterval,
        (_) => _onPollTick(),
      );
    } else {
      _stopPolling();
    }
    state = next.withLivePolling(poll);
  }

  bool _shouldPoll(TeacherBlitzMonitoringState next) {
    return _isAlive &&
        _routeOwned &&
        _appResumed &&
        !_dialogHold &&
        !_grantOwnsRoute &&
        _sessionKey != null &&
        _identity == TeacherBlitzParentIdentity.confirmed &&
        !next.hasEnded &&
        !next.pollingPausedByRateLimit;
  }

  void _abandonActiveRead() {
    final before = _stateBeforeRead;
    _cancelRead();
    _publish(before ?? state);
  }

  void _cancelRead() {
    _generation += 1;
    _requestActive = false;
    _stateBeforeRead = null;
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _resetOwnership() {
    _routeEpoch += 1;
    _dialogHold = false;
    // The grant controller abandons its operation on the same change.
    _grantOwnsRoute = false;
    _cancelRead();
  }

  bool _canPublish(int generation, TeacherSessionKey sessionKey) {
    return _isAlive &&
        _requestActive &&
        generation == _generation &&
        !_routeLeft &&
        _identity == TeacherBlitzParentIdentity.confirmed &&
        _matchesSession(sessionKey);
  }

  bool _matchesSession(TeacherSessionKey sessionKey) {
    return _isAlive &&
        _sessionKey == sessionKey &&
        _currentSessionKey() == sessionKey;
  }

  TeacherSessionKey? _currentSessionKey() {
    return TeacherSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
  }

  TeacherBlitzParentIdentity _currentIdentity() {
    return teacherBlitzParentIdentity(
      ref.read(teacherBlitzDetailControllerProvider(target)),
      target,
    );
  }

  bool _isSessionFailure(ApiFailure failure) {
    return failure.serverCode == ApiErrorCodes.authenticationRequired ||
        failure.serverCode == ApiErrorCodes.passwordChangeRequired ||
        failure.serverCode == ApiErrorCodes.userInactive ||
        failure.serverCode == ApiErrorCodes.institutionInactive;
  }

  void _clearForSessionFailure(ApiFailure failure) {
    _resetOwnership();
    _sessionKey = null;
    _identity = null;
    _publish(const TeacherBlitzMonitoringState());
    if (failure.serverCode != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
  }

  void _dispose() {
    _disposed = true;
    _stopPolling();
    _cancelRead();
  }
}

TeacherBlitzMonitoringStatus? _endedStatus(ApiFailure failure) {
  if (failure.statusCode == 404 &&
      failure.serverCode == ApiErrorCodes.resourceNotFound) {
    return TeacherBlitzMonitoringStatus.notFound;
  }
  if (failure.statusCode != 409) {
    return null;
  }
  return switch (failure.serverCode) {
    ApiErrorCodes.taskNotActive => TeacherBlitzMonitoringStatus.notActive,
    ApiErrorCodes.taskClosed => TeacherBlitzMonitoringStatus.closed,
    ApiErrorCodes.taskArchived => TeacherBlitzMonitoringStatus.archived,
    _ => null,
  };
}
