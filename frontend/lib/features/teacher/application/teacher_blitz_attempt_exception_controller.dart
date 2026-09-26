import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/idempotency_key_generator.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_blitz_repository_impl.dart';
import '../domain/teacher_blitz_attempt_exception.dart';
import '../domain/teacher_blitz_monitoring.dart';
import 'teacher_blitz_attempt_exception_state.dart';
import 'teacher_blitz_detail_controller.dart';
import 'teacher_blitz_monitoring_controller.dart';
import 'teacher_blitz_parent_identity.dart';
import 'teacher_blitz_route_target.dart';
import 'teacher_session_key.dart';

final teacherBlitzAttemptExceptionControllerProvider = NotifierProvider
    .autoDispose
    .family<
      TeacherBlitzAttemptExceptionController,
      TeacherBlitzAttemptExceptionState,
      TeacherBlitzRouteTarget
    >(TeacherBlitzAttemptExceptionController.new);

const _uncertainMessage =
    'We could not confirm whether the additional attempt was granted.';
const _monitoringEndedMessage =
    'Live monitoring is no longer available for this Blitz. Retry the '
    'original grant request to confirm whether it was recorded.';
const _statusChangedMessage =
    "The Student's Blitz status changed. Review current monitoring before "
    'granting an additional attempt.';

/// Ownership captured when the grant dialog opens; a dialog result from an
/// older session, route or parent identity is ignored.
class TeacherBlitzAttemptExceptionTicket {
  const TeacherBlitzAttemptExceptionTicket._({
    required this.sessionKey,
    required this.studentId,
    required this.monitoringEpoch,
  });

  final TeacherSessionKey sessionKey;
  final String studentId;
  final int monitoringEpoch;
}

/// One desktop additional-attempt grant at a time for a monitored Blitz.
class TeacherBlitzAttemptExceptionController
    extends Notifier<TeacherBlitzAttemptExceptionState> {
  TeacherBlitzAttemptExceptionController(this.target);

  final TeacherBlitzRouteTarget target;
  TeacherSessionKey? _activeSessionKey;
  _PendingGrant? _pending;
  var _operationGeneration = 0;

  @override
  TeacherBlitzAttemptExceptionState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    final identity = ref.watch(
      teacherBlitzDetailControllerProvider(
        target,
      ).select((detail) => teacherBlitzParentIdentity(detail, target)),
    );
    // Losing the session or the confirmed parent abandons any pending grant.
    if (sessionKey == null ||
        sessionKey.surface != AppDeviceSurface.desktop ||
        identity != TeacherBlitzParentIdentity.confirmed) {
      _clearSession();
      return const TeacherBlitzAttemptExceptionState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearSession();
    _activeSessionKey = sessionKey;
    return const TeacherBlitzAttemptExceptionState();
  }

  /// Captures ownership before the grant dialog opens, or null when the
  /// Student is not a current grant candidate.
  TeacherBlitzAttemptExceptionTicket? prepare(String studentId) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        !_matchesSession(sessionKey) ||
        state.ownsMonitoring ||
        _candidate(studentId) == null) {
      return null;
    }
    return TeacherBlitzAttemptExceptionTicket._(
      sessionKey: sessionKey,
      studentId: studentId,
      monitoringEpoch: _monitoring.routeEpoch,
    );
  }

  Future<void> grant(
    TeacherBlitzAttemptExceptionTicket ticket,
    TeacherBlitzAttemptExceptionRequest request,
  ) async {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        ticket.sessionKey != sessionKey ||
        !_matchesSession(sessionKey) ||
        state.ownsMonitoring ||
        ticket.monitoringEpoch != _monitoring.routeEpoch) {
      return;
    }
    // Backend eligibility is final; this only stops a grant for a row that
    // changed while the dialog was open.
    if (_candidate(ticket.studentId) == null) {
      _emit(
        TeacherBlitzAttemptExceptionState(
          status: TeacherBlitzAttemptExceptionStatus.failure,
          studentId: ticket.studentId,
          message: _statusChangedMessage,
        ),
      );
      return;
    }
    final pending = _PendingGrant(
      sessionKey: sessionKey,
      studentId: ticket.studentId,
      request: request,
      idempotencyKey: ref.read(idempotencyKeyGeneratorProvider).generate(),
    );
    _pending = pending;
    await _send(pending);
  }

  /// Resends the unresolved grant with its original key and request.
  Future<void> retryGrant() async {
    final pending = _pending;
    if (pending == null ||
        state.status != TeacherBlitzAttemptExceptionStatus.uncertain ||
        !state.canRetry ||
        !_matchesSession(pending.sessionKey)) {
      return;
    }
    await _send(pending);
  }

  /// Reads Active monitoring to learn whether the unresolved grant exists;
  /// never replays it.
  Future<void> checkMonitoring() async {
    final pending = _pending;
    if (pending == null ||
        state.status != TeacherBlitzAttemptExceptionStatus.uncertain ||
        !state.canCheckMonitoring ||
        !_matchesSession(pending.sessionKey)) {
      return;
    }
    final generation = ++_operationGeneration;
    final monitoring = _monitoring;
    _emit(
      TeacherBlitzAttemptExceptionState(
        status: TeacherBlitzAttemptExceptionStatus.checking,
        studentId: pending.studentId,
      ),
    );
    final result = await monitoring.readForGrant();
    if (!_canPublish(generation, pending)) {
      return;
    }
    final row = result?.currentMonitoring?.studentById(pending.studentId);
    if (row?.attemptException != null) {
      _confirm(
        pending,
        'An additional attempt is now granted to this Student.',
      );
      return;
    }
    _publishUncertain(pending);
  }

  /// Clears a settled outcome message.
  void dismiss() {
    if (state.status == TeacherBlitzAttemptExceptionStatus.confirmed ||
        state.status == TeacherBlitzAttemptExceptionStatus.failure) {
      state = const TeacherBlitzAttemptExceptionState();
    }
  }

  /// Publishes [next] and hands monitoring-route ownership to match it.
  void _emit(TeacherBlitzAttemptExceptionState next) {
    state = next;
    _monitoring.setGrantOwnership(next.ownsMonitoring);
  }

  TeacherBlitzMonitoringController get _monitoring =>
      ref.read(teacherBlitzMonitoringControllerProvider(target).notifier);

  TeacherBlitzMonitoringStudent? _candidate(String studentId) {
    final row = ref
        .read(teacherBlitzMonitoringControllerProvider(target))
        .currentMonitoring
        ?.studentById(studentId);
    return row != null && row.isGrantCandidate ? row : null;
  }

  Future<void> _send(_PendingGrant pending) async {
    final generation = ++_operationGeneration;
    final repository = ref.read(teacherBlitzRepositoryProvider);
    final monitoring = _monitoring;
    _emit(
      TeacherBlitzAttemptExceptionState(
        status: TeacherBlitzAttemptExceptionStatus.submitting,
        studentId: pending.studentId,
      ),
    );
    try {
      final exception = await repository.grantAttemptException(
        target.blitzId,
        pending.studentId,
        pending.request,
        idempotencyKey: pending.idempotencyKey,
      );
      if (!_canPublish(generation, pending)) {
        return;
      }
      if (exception.blitzId.toLowerCase() != target.blitzId.toLowerCase() ||
          exception.studentId.toLowerCase() !=
              pending.studentId.toLowerCase()) {
        _publishUncertain(pending);
        return;
      }
      // The grant alone never patches a row; monitoring stays the source.
      _confirm(pending, _grantedMessage(exception.replacementState));
      await monitoring.readForGrant();
    } on TeacherBlitzAttemptExceptionOutcomeUnknownException {
      if (_canPublish(generation, pending)) {
        _publishUncertain(pending);
      }
    } on ApiRequestException catch (exception) {
      if (_canPublish(generation, pending)) {
        await _publishDefiniteFailure(
          generation,
          pending,
          exception.failure,
          monitoring,
        );
      }
    } catch (_) {
      if (_canPublish(generation, pending)) {
        _publishUncertain(pending);
      }
    }
  }

  Future<void> _publishDefiniteFailure(
    int generation,
    _PendingGrant pending,
    ApiFailure failure,
    TeacherBlitzMonitoringController monitoring,
  ) async {
    if (_isSessionFailure(failure)) {
      _clearForSessionFailure(failure);
      return;
    }
    if (failure.statusCode == 409 &&
        failure.serverCode ==
            ApiErrorCodes.blitzAttemptExceptionAlreadyGranted) {
      _emit(
        TeacherBlitzAttemptExceptionState(
          status: TeacherBlitzAttemptExceptionStatus.checking,
          studentId: pending.studentId,
        ),
      );
      final result = await monitoring.readForGrant();
      if (!_canPublish(generation, pending)) {
        return;
      }
      final row = result?.currentMonitoring?.studentById(pending.studentId);
      if (row?.attemptException != null) {
        _confirm(
          pending,
          'An additional attempt has already been granted to this Student.',
        );
      } else {
        _fail(
          pending,
          'An additional attempt was already granted, but current '
          "monitoring could not confirm it.\nRefresh monitoring to review the "
          "Student's current attempt.",
        );
      }
      return;
    }
    _fail(pending, _definiteFailureMessage(failure));
    await monitoring.readForGrant();
  }

  void _confirm(_PendingGrant pending, String message) {
    _pending = null;
    _emit(
      TeacherBlitzAttemptExceptionState(
        status: TeacherBlitzAttemptExceptionStatus.confirmed,
        studentId: pending.studentId,
        message: message,
      ),
    );
  }

  void _fail(_PendingGrant pending, String message) {
    _pending = null;
    _emit(
      TeacherBlitzAttemptExceptionState(
        status: TeacherBlitzAttemptExceptionStatus.failure,
        studentId: pending.studentId,
        message: message,
      ),
    );
  }

  /// Keeps the key and request; only a same-key Retry or a monitoring check
  /// may resolve the outcome.
  void _publishUncertain(_PendingGrant pending) {
    // Active-only monitoring cannot prove a grant once live monitoring ended.
    final monitoringEnded = ref
        .read(teacherBlitzMonitoringControllerProvider(target))
        .hasEnded;
    _emit(
      TeacherBlitzAttemptExceptionState(
        status: TeacherBlitzAttemptExceptionStatus.uncertain,
        studentId: pending.studentId,
        message: monitoringEnded ? _monitoringEndedMessage : _uncertainMessage,
        canRetry: true,
        canCheckMonitoring: !monitoringEnded,
      ),
    );
  }

  bool _canPublish(int generation, _PendingGrant pending) {
    return ref.mounted &&
        generation == _operationGeneration &&
        identical(_pending, pending) &&
        _matchesSession(pending.sessionKey);
  }

  bool _matchesSession(TeacherSessionKey sessionKey) {
    return ref.mounted &&
        _activeSessionKey == sessionKey &&
        sessionKey.surface == AppDeviceSurface.desktop &&
        TeacherSessionSnapshot.fromSession(
              ref.read(authSessionControllerProvider),
              ref.read(appDeviceSurfaceProvider),
            ).eligibleKey ==
            sessionKey &&
        teacherBlitzParentIdentity(
              ref.read(teacherBlitzDetailControllerProvider(target)),
              target,
            ) ==
            TeacherBlitzParentIdentity.confirmed;
  }

  bool _isSessionFailure(ApiFailure failure) {
    return failure.serverCode == ApiErrorCodes.authenticationRequired ||
        failure.serverCode == ApiErrorCodes.passwordChangeRequired ||
        failure.serverCode == ApiErrorCodes.userInactive ||
        failure.serverCode == ApiErrorCodes.institutionInactive;
  }

  void _clearForSessionFailure(ApiFailure failure) {
    _clearSession();
    _emit(const TeacherBlitzAttemptExceptionState());
    if (failure.serverCode != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
  }

  void _clearSession() {
    _operationGeneration += 1;
    _activeSessionKey = null;
    _pending = null;
  }
}

/// The immutable request of one logical grant and its private key.
class _PendingGrant {
  const _PendingGrant({
    required this.sessionKey,
    required this.studentId,
    required this.request,
    required this.idempotencyKey,
  });

  final TeacherSessionKey sessionKey;
  final String studentId;
  final TeacherBlitzAttemptExceptionRequest request;
  final String idempotencyKey;
}

String _grantedMessage(TeacherBlitzAttemptExceptionReplacementState state) {
  return switch (state) {
    TeacherBlitzAttemptExceptionReplacementState.available =>
      'Additional Blitz attempt granted.',
    TeacherBlitzAttemptExceptionReplacementState.noLongerAvailable =>
      'Additional-attempt grant confirmed, but the Blitz no longer allows '
          'the Student to start that attempt.',
    TeacherBlitzAttemptExceptionReplacementState.started =>
      'Additional-attempt grant confirmed. The additional attempt has '
          'already been started.',
  };
}

String _definiteFailureMessage(ApiFailure failure) {
  if (failure.statusCode == 404 &&
      failure.serverCode == ApiErrorCodes.resourceNotFound) {
    return 'The Student or Blitz is no longer available for this action.';
  }
  return switch (failure.serverCode) {
    ApiErrorCodes.blitzAttemptExceptionNotAllowed =>
      'An additional attempt cannot be granted in the current Blitz state.\n'
          "Refresh monitoring to review the Student's current attempt.",
    ApiErrorCodes.blitzNormalAttemptRequired =>
      'The Student must have a normal Blitz attempt before an additional '
          'attempt can be granted.',
    ApiErrorCodes.idempotencyKeyReused =>
      'The additional-attempt request could not be replayed safely.\n'
          'Refresh monitoring before trying again.',
    ApiErrorCodes.forbidden =>
      'You do not have permission to grant an additional attempt.',
    ApiErrorCodes.validationFailed =>
      'The additional-attempt request was not accepted.\nReview the reason '
          'and try again.',
    ApiErrorCodes.rateLimited => 'Too many requests. Wait before trying again.',
    _ => 'The additional attempt could not be granted.',
  };
}
