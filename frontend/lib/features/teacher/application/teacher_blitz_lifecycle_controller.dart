import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/idempotency_key_generator.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/teacher_blitz_repository_impl.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_lifecycle.dart';
import '../domain/teacher_blitz_mutation.dart';
import '../domain/teacher_blitz_schedule.dart';
import 'teacher_blitz_detail_controller.dart';
import 'teacher_blitz_detail_state.dart';
import 'teacher_blitz_lifecycle_state.dart';
import 'teacher_blitz_list_controller.dart';
import 'teacher_blitz_route_mutation_activity.dart';
import 'teacher_blitz_route_target.dart';
import 'teacher_question_mutation_activity.dart';
import 'teacher_session_key.dart';
import 'teacher_topic_result_pair_controller.dart';
import 'teacher_topic_result_pair_state.dart';

final teacherBlitzLifecycleControllerProvider = NotifierProvider.autoDispose
    .family<
      TeacherBlitzLifecycleController,
      TeacherBlitzLifecycleState,
      TeacherBlitzRouteTarget
    >(TeacherBlitzLifecycleController.new);

/// What a confirmed pair read proves about [blitz]; loading, errors and
/// stale retained values prove nothing.
TeacherBlitzOfficialKnowledge teacherBlitzOfficialKnowledge(
  TeacherBlitz blitz,
  TeacherTopicResultPairState pairState,
) {
  if (!pairState.hasConfirmedData) {
    return TeacherBlitzOfficialKnowledge.unconfirmed;
  }
  return pairState.pair?.blitzAssessmentId?.toLowerCase() ==
          blitz.id.toLowerCase()
      ? TeacherBlitzOfficialKnowledge.official
      : TeacherBlitzOfficialKnowledge.notOfficial;
}

/// Mobile may only Activate; every other lifecycle action is desktop-only.
bool isTeacherBlitzLifecycleActionOnSurface(
  TeacherBlitzLifecycleAction action,
  AppDeviceSurface surface,
) {
  return surface == AppDeviceSurface.desktop ||
      action == TeacherBlitzLifecycleAction.activate;
}

const _scheduleUnconfirmed =
    'The schedule update could not be confirmed.\nReview the current Blitz '
    'schedule before trying again.';
const _activationUnconfirmed =
    'The activation result could not be confirmed.\nReview the current Blitz '
    'before trying again.';
const _currentUnconfirmed =
    'The current Blitz could not be confirmed.\nCheck the current Blitz '
    'before taking another action.';

class TeacherBlitzLifecycleController
    extends Notifier<TeacherBlitzLifecycleState> {
  TeacherBlitzLifecycleController(this.target);

  final TeacherBlitzRouteTarget target;
  TeacherSessionKey? _activeSessionKey;
  _LifecycleOperation? _activeOperation;
  _LifecycleOperation? _reviewedOperation;
  String? _pendingActivationKey;
  var _operationGeneration = 0;

  String get _topicKey => target.topicId.toLowerCase();

  @override
  TeacherBlitzLifecycleState build() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (sessionKey == null) {
      _clearSession();
      return const TeacherBlitzLifecycleState();
    }
    if (_activeSessionKey == sessionKey) {
      return state;
    }

    _clearSession();
    _activeSessionKey = sessionKey;
    return const TeacherBlitzLifecycleState();
  }

  Future<void> schedule(TeacherBlitzScheduleRequest request) async {
    const action = TeacherBlitzLifecycleAction.schedule;
    final blitz = _mutableBlitz(action);
    if (blitz == null) {
      return;
    }
    if (request.isNoOpFor(blitz)) {
      _emit(
        const TeacherBlitzLifecycleState(
          action: action,
          notice: 'Blitz is already scheduled for this time.',
        ),
      );
      return;
    }
    await _run(
      action: action,
      scheduleRequest: request,
      send: (_) => ref
          .read(teacherBlitzRepositoryProvider)
          .scheduleBlitz(target.blitzId, request),
    );
  }

  Future<void> activate() async {
    // An unresolved activation keeps its key; only Retry may send it again.
    if (_pendingActivationKey != null ||
        _mutableBlitz(TeacherBlitzLifecycleAction.activate) == null) {
      return;
    }
    await _activate(TeacherBlitzActivationSendKind.initialSend);
  }

  /// Resends the unresolved activation with its original Idempotency-Key.
  Future<void> retryActivation() async {
    final blitz = _mutableBlitz(TeacherBlitzLifecycleAction.activate);
    if (_pendingActivationKey == null ||
        !state.canRetryActivation ||
        blitz == null) {
      return;
    }
    await _activate(TeacherBlitzActivationSendKind.sameKeyRetry);
  }

  Future<void> close() async {
    const action = TeacherBlitzLifecycleAction.close;
    if (_mutableBlitz(action) == null) {
      return;
    }
    await _run(
      action: action,
      send: (_) =>
          ref.read(teacherBlitzRepositoryProvider).closeBlitz(target.blitzId),
    );
  }

  Future<void> archive() async {
    const action = TeacherBlitzLifecycleAction.archive;
    if (_mutableBlitz(action) == null) {
      return;
    }
    await _run(
      action: action,
      send: (_) =>
          ref.read(teacherBlitzRepositoryProvider).archiveBlitz(target.blitzId),
    );
  }

  /// Reads the exact current Blitz for an unresolved outcome; never replays.
  Future<void> checkCurrentBlitz() async {
    final reviewed = _reviewedOperation;
    final sessionKey = _activeSessionKey;
    if (!state.canCheckCurrent ||
        reviewed == null ||
        sessionKey == null ||
        !_matchesSession(sessionKey)) {
      return;
    }
    final activity = ref.read(
      teacherBlitzRouteMutationActivityProvider(target).notifier,
    );
    var lease = _activeOperation?.lease;
    if (lease == null || !activity.owns(lease)) {
      if (_otherMutationActive()) {
        return;
      }
      lease = activity.begin(_leaseOperation(reviewed.action));
      if (lease == null) {
        return;
      }
    }
    final operation = reviewed.withLease(lease, ++_operationGeneration);
    _activeOperation = operation;
    try {
      await _reconcileUnknown(operation);
    } finally {
      _releaseIfAbandoned(activity, lease);
    }
  }

  void consumeFeedback() {
    if (state.feedback != null) {
      state = state.withoutFeedback();
    }
  }

  /// Clears a settled notice; outcome reviews stay until they are resolved.
  void clearNotice() {
    if (state.isBusy || state.canCheckCurrent || state.notice == null) {
      return;
    }
    _emit(const TeacherBlitzLifecycleState());
  }

  void invalidateRouteCompletions() {
    _operationGeneration += 1;
  }

  void leaveRoute() {
    invalidateRouteCompletions();
    _pendingActivationKey = null;
    _releaseActiveLease();
    if (ref.mounted) {
      _emit(const TeacherBlitzLifecycleState());
    }
  }

  /// Publishes [next] with Retry availability derived from the pending key.
  void _emit(TeacherBlitzLifecycleState next) {
    state = next.withRetryAvailability(
      _pendingActivationKey != null &&
          !next.isBusy &&
          !next.requiresCheckCurrent,
    );
  }

  Future<void> _activate(TeacherBlitzActivationSendKind sendKind) {
    return _run(
      action: TeacherBlitzLifecycleAction.activate,
      sendKind: sendKind,
      // The key is generated only after the lease proves current ownership.
      send: (_) {
        final key = _pendingActivationKey ??= ref
            .read(idempotencyKeyGeneratorProvider)
            .generate();
        return ref
            .read(teacherBlitzRepositoryProvider)
            .activateBlitz(target.blitzId, idempotencyKey: key);
      },
    );
  }

  Future<void> _run({
    required TeacherBlitzLifecycleAction action,
    required Future<TeacherBlitz> Function(_LifecycleOperation operation) send,
    TeacherBlitzScheduleRequest? scheduleRequest,
    TeacherBlitzActivationSendKind? sendKind,
  }) async {
    final activity = ref.read(
      teacherBlitzRouteMutationActivityProvider(target).notifier,
    );
    final lease = activity.begin(_leaseOperation(action));
    if (lease == null) {
      return;
    }
    final operation = _LifecycleOperation(
      action: action,
      lease: lease,
      generation: ++_operationGeneration,
      scheduleRequest: scheduleRequest,
      sendKind: sendKind,
    );
    _activeOperation = operation;
    _reviewedOperation = null;
    _emit(
      TeacherBlitzLifecycleState(
        status: TeacherBlitzLifecycleStatus.submitting,
        action: action,
      ),
    );
    try {
      final returned = await send(operation);
      if (!_canPublish(operation)) {
        return;
      }
      if (_isConfirmedResult(operation, returned)) {
        _publishSuccess(operation, returned);
      } else {
        await _reconcileUnknown(operation);
      }
    } on TeacherBlitzMutationOutcomeUnknownException {
      await _reconcileUnknown(operation);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation)) {
        return;
      }
      final failure = exception.failure;
      if (_isSessionFailure(failure)) {
        _clearForSessionFailure(failure);
        return;
      }
      if (_isNotFound(failure)) {
        _publishUnavailable(operation);
        return;
      }
      if (action == TeacherBlitzLifecycleAction.activate) {
        _pendingActivationKey = null;
      }
      if (failure.statusCode == 409) {
        await _publishConflictAfterRefresh(operation, failure.serverCode);
        return;
      }
      _publishDefiniteFailure(
        operation,
        conflictCode: failure.serverCode,
        notice: _definiteFailureMessage(action, failure),
      );
    } catch (_) {
      await _reconcileUnknown(operation);
    } finally {
      _releaseIfAbandoned(activity, lease);
    }
  }

  bool _isConfirmedResult(_LifecycleOperation operation, TeacherBlitz blitz) {
    if (!_matchesTarget(blitz)) {
      return false;
    }
    return switch (operation.action) {
      TeacherBlitzLifecycleAction.schedule =>
        operation.scheduleRequest!.isConfirmedBy(blitz),
      TeacherBlitzLifecycleAction.activate => isAcceptedTeacherBlitzActivation(
        blitz,
        operation.sendKind!,
      ),
      TeacherBlitzLifecycleAction.close =>
        blitz.status == TeacherBlitzStatus.closed,
      TeacherBlitzLifecycleAction.archive =>
        blitz.status == TeacherBlitzStatus.archived,
    };
  }

  Future<void> _reconcileUnknown(_LifecycleOperation operation) async {
    if (!_canPublish(operation)) {
      return;
    }
    _emit(
      TeacherBlitzLifecycleState(
        status: TeacherBlitzLifecycleStatus.reconciling,
        action: operation.action,
      ),
    );
    try {
      final current = await ref
          .read(teacherBlitzRepositoryProvider)
          .fetchBlitz(target.blitzId);
      if (!_canPublish(operation)) {
        return;
      }
      if (!_matchesTarget(current)) {
        _publishBlockingReview(operation);
        return;
      }
      _acceptAuthoritativeBlitz(current, operation.lease.sessionKey);
      _classifyCurrent(operation, current);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation)) {
        return;
      }
      if (_isSessionFailure(exception.failure)) {
        _clearForSessionFailure(exception.failure);
        return;
      }
      if (_isNotFound(exception.failure)) {
        _publishUnavailable(operation);
        return;
      }
      _publishBlockingReview(operation);
    } catch (_) {
      if (_canPublish(operation)) {
        _publishBlockingReview(operation);
      }
    }
  }

  void _classifyCurrent(_LifecycleOperation operation, TeacherBlitz current) {
    switch (operation.action) {
      case TeacherBlitzLifecycleAction.schedule:
        if (operation.scheduleRequest!.isConfirmedBy(current)) {
          _publishSuccess(operation, current);
        } else {
          _publishReview(operation, _scheduleUnconfirmed);
        }
      case TeacherBlitzLifecycleAction.activate:
        switch (current.status) {
          case TeacherBlitzStatus.active:
            _publishSuccess(operation, current, reconciled: true);
          case TeacherBlitzStatus.draft || TeacherBlitzStatus.scheduled:
            // The same key stays pending so an explicit Retry cannot
            // create a second logical activation.
            _publishReview(operation, _activationUnconfirmed);
          case TeacherBlitzStatus.closed || TeacherBlitzStatus.archived:
            _pendingActivationKey = null;
            _publishReview(operation, _activationUnconfirmed);
        }
      case TeacherBlitzLifecycleAction.close:
        if (current.status == TeacherBlitzStatus.closed) {
          _publishSuccess(operation, current);
        } else {
          _publishReview(
            operation,
            'The close result could not be confirmed.\nReview the current '
            'Blitz before trying again.',
          );
        }
      case TeacherBlitzLifecycleAction.archive:
        if (current.status == TeacherBlitzStatus.archived) {
          _publishSuccess(operation, current);
        } else {
          _publishReview(
            operation,
            'The archive result could not be confirmed.\nReview the current '
            'Blitz before trying again.',
          );
        }
    }
  }

  Future<void> _publishConflictAfterRefresh(
    _LifecycleOperation operation,
    String? conflictCode,
  ) async {
    _emit(
      TeacherBlitzLifecycleState(
        status: TeacherBlitzLifecycleStatus.reconciling,
        action: operation.action,
      ),
    );
    if (_refreshesPairOnConflict(operation.action, conflictCode)) {
      _refreshResultPair(operation.lease.sessionKey);
    }
    try {
      final current = await ref
          .read(teacherBlitzRepositoryProvider)
          .fetchBlitz(target.blitzId);
      if (_canPublish(operation) && _matchesTarget(current)) {
        _acceptAuthoritativeBlitz(current, operation.lease.sessionKey);
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublish(operation)) {
        return;
      }
      if (_isSessionFailure(exception.failure)) {
        _clearForSessionFailure(exception.failure);
        return;
      }
      if (_isNotFound(exception.failure)) {
        _publishUnavailable(operation);
        return;
      }
      // The mutation failure is already definite; a failed best-effort read
      // must not turn it into an unknown outcome or cause a replay.
    } catch (_) {
      // Same as above: the definite conflict stands.
    }
    if (!_canPublish(operation)) {
      return;
    }
    _publishDefiniteFailure(
      operation,
      conflictCode: conflictCode,
      notice: _conflictMessage(
        operation.action,
        conflictCode,
        operation.lease.sessionKey.surface,
      ),
    );
  }

  void _publishSuccess(
    _LifecycleOperation operation,
    TeacherBlitz blitz, {
    bool reconciled = false,
  }) {
    final sessionKey = operation.lease.sessionKey;
    _acceptAuthoritativeBlitz(blitz, sessionKey);
    _refreshBlitzList(sessionKey);
    if (operation.action == TeacherBlitzLifecycleAction.activate) {
      _pendingActivationKey = null;
      // Activation may have snapshotted the official cohort.
      _refreshResultPair(sessionKey);
    }
    _finishOperation(operation);
    _emit(
      TeacherBlitzLifecycleState(
        status: TeacherBlitzLifecycleStatus.confirmedSuccess,
        action: operation.action,
        feedback: _successFeedback(operation.action, blitz, reconciled),
      ),
    );
  }

  void _publishReview(_LifecycleOperation operation, String notice) {
    _finishOperation(operation);
    _reviewedOperation = operation;
    _emit(
      TeacherBlitzLifecycleState(
        status: TeacherBlitzLifecycleStatus.outcomeReview,
        action: operation.action,
        notice: notice,
      ),
    );
  }

  void _publishBlockingReview(_LifecycleOperation operation) {
    // The lease stays held until the Teacher checks the current Blitz.
    _reviewedOperation = operation;
    _emit(
      TeacherBlitzLifecycleState(
        status: TeacherBlitzLifecycleStatus.outcomeReview,
        action: operation.action,
        notice: _currentUnconfirmed,
        requiresCheckCurrent: true,
      ),
    );
  }

  void _publishDefiniteFailure(
    _LifecycleOperation operation, {
    required String? conflictCode,
    required String notice,
  }) {
    _finishOperation(operation);
    _emit(
      TeacherBlitzLifecycleState(
        status: TeacherBlitzLifecycleStatus.definiteFailure,
        action: operation.action,
        notice: notice,
        conflictCode: conflictCode,
      ),
    );
  }

  void _publishUnavailable(_LifecycleOperation operation) {
    final sessionKey = operation.lease.sessionKey;
    ref
        .read(teacherBlitzDetailControllerProvider(target).notifier)
        .markNotFound(sessionKey);
    _refreshBlitzList(sessionKey);
    _pendingActivationKey = null;
    _finishOperation(operation);
    _emit(
      TeacherBlitzLifecycleState(
        status: TeacherBlitzLifecycleStatus.unavailable,
        action: operation.action,
        notice: 'This Blitz is no longer available.',
      ),
    );
  }

  /// Returns the confirmed Blitz when [action] may start now.
  TeacherBlitz? _mutableBlitz(TeacherBlitzLifecycleAction action) {
    final sessionKey = _activeSessionKey;
    if (sessionKey == null ||
        !_matchesSession(sessionKey) ||
        !isTeacherBlitzLifecycleActionOnSurface(action, sessionKey.surface) ||
        state.blocksMutations ||
        _otherMutationActive()) {
      return null;
    }
    final detail = ref.read(teacherBlitzDetailControllerProvider(target));
    final blitz = detail.blitz;
    if (detail.status != TeacherBlitzDetailStatus.data ||
        detail.isStale ||
        blitz == null ||
        !_matchesTarget(blitz)) {
      return null;
    }
    final pairProvider = teacherTopicResultPairControllerProvider(_topicKey);
    final official = ref.exists(pairProvider)
        ? teacherBlitzOfficialKnowledge(blitz, ref.read(pairProvider))
        : TeacherBlitzOfficialKnowledge.unconfirmed;
    if (!teacherBlitzLifecycleActions(
      blitz,
      official: official,
    ).contains(action)) {
      return null;
    }
    return blitz;
  }

  bool _otherMutationActive() {
    final routeProvider = teacherBlitzRouteMutationActivityProvider(target);
    final questionProvider = teacherQuestionMutationActivityProvider(target);
    return (ref.exists(routeProvider) && ref.read(routeProvider).isActive) ||
        (ref.exists(questionProvider) && ref.read(questionProvider).isActive);
  }

  void _acceptAuthoritativeBlitz(
    TeacherBlitz blitz,
    TeacherSessionKey sessionKey,
  ) {
    ref
        .read(teacherBlitzDetailControllerProvider(target).notifier)
        .acceptAuthoritativeBlitz(blitz, sessionKey);
  }

  void _refreshBlitzList(TeacherSessionKey sessionKey) {
    final provider = teacherBlitzListControllerProvider(_topicKey);
    if (ref.exists(provider)) {
      ref.read(provider.notifier).refreshAfterMutation(sessionKey);
    } else {
      ref.invalidate(provider);
    }
  }

  void _refreshResultPair(TeacherSessionKey sessionKey) {
    final provider = teacherTopicResultPairControllerProvider(_topicKey);
    if (ref.exists(provider)) {
      unawaited(ref.read(provider.notifier).refreshAfterMutation(sessionKey));
    }
  }

  bool _matchesTarget(TeacherBlitz blitz) {
    return blitz.id.toLowerCase() == target.blitzId.toLowerCase() &&
        blitz.topicId.toLowerCase() == target.topicId.toLowerCase();
  }

  bool _canPublish(_LifecycleOperation operation) {
    return ref.mounted &&
        operation.generation == _operationGeneration &&
        identical(_activeOperation, operation) &&
        ref
            .read(teacherBlitzRouteMutationActivityProvider(target).notifier)
            .owns(operation.lease) &&
        _matchesSession(operation.lease.sessionKey);
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

  bool _isSessionFailure(ApiFailure failure) {
    return failure.serverCode == ApiErrorCodes.authenticationRequired ||
        failure.serverCode == ApiErrorCodes.passwordChangeRequired ||
        failure.serverCode == ApiErrorCodes.userInactive ||
        failure.serverCode == ApiErrorCodes.institutionInactive;
  }

  bool _isNotFound(ApiFailure failure) {
    return failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound;
  }

  void _clearForSessionFailure(ApiFailure failure) {
    _clearSession();
    _emit(const TeacherBlitzLifecycleState());
    if (failure.serverCode != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
  }

  void _finishOperation(_LifecycleOperation operation) {
    if (identical(_activeOperation, operation)) {
      _activeOperation = null;
    }
    ref
        .read(teacherBlitzRouteMutationActivityProvider(target).notifier)
        .release(operation.lease);
  }

  void _releaseIfAbandoned(
    TeacherBlitzRouteMutationActivityController activity,
    TeacherBlitzRouteMutationLease lease,
  ) {
    final remainsBlocking =
        ref.mounted &&
        identical(_activeOperation?.lease, lease) &&
        state.hasBlockingOutcome &&
        activity.owns(lease);
    if (!remainsBlocking) {
      activity.release(lease);
    }
  }

  void _releaseActiveLease() {
    final lease = _activeOperation?.lease;
    _activeOperation = null;
    _reviewedOperation = null;
    if (lease != null && ref.mounted) {
      ref
          .read(teacherBlitzRouteMutationActivityProvider(target).notifier)
          .release(lease);
    }
  }

  void _clearSession() {
    _operationGeneration += 1;
    _activeSessionKey = null;
    _pendingActivationKey = null;
    _releaseActiveLease();
  }
}

/// The immutable context of one lifecycle POST or its reconciliation.
class _LifecycleOperation {
  const _LifecycleOperation({
    required this.action,
    required this.lease,
    required this.generation,
    this.scheduleRequest,
    this.sendKind,
  });

  final TeacherBlitzLifecycleAction action;
  final TeacherBlitzRouteMutationLease lease;
  final int generation;
  final TeacherBlitzScheduleRequest? scheduleRequest;
  final TeacherBlitzActivationSendKind? sendKind;

  _LifecycleOperation withLease(
    TeacherBlitzRouteMutationLease nextLease,
    int nextGeneration,
  ) {
    return _LifecycleOperation(
      action: action,
      lease: nextLease,
      generation: nextGeneration,
      scheduleRequest: scheduleRequest,
      sendKind: sendKind,
    );
  }
}

TeacherBlitzRouteMutationOperation _leaseOperation(
  TeacherBlitzLifecycleAction action,
) {
  return switch (action) {
    TeacherBlitzLifecycleAction.schedule =>
      TeacherBlitzRouteMutationOperation.schedule,
    TeacherBlitzLifecycleAction.activate =>
      TeacherBlitzRouteMutationOperation.activate,
    TeacherBlitzLifecycleAction.close =>
      TeacherBlitzRouteMutationOperation.close,
    TeacherBlitzLifecycleAction.archive =>
      TeacherBlitzRouteMutationOperation.archive,
  };
}

bool _refreshesPairOnConflict(
  TeacherBlitzLifecycleAction action,
  String? code,
) {
  return switch (action) {
    TeacherBlitzLifecycleAction.archive =>
      code == ApiErrorCodes.businessConflict,
    TeacherBlitzLifecycleAction.activate =>
      code == ApiErrorCodes.officialCohortMismatch ||
          code == ApiErrorCodes.businessConflict,
    _ => false,
  };
}

String _successFeedback(
  TeacherBlitzLifecycleAction action,
  TeacherBlitz blitz,
  bool reconciled,
) {
  return switch (action) {
    TeacherBlitzLifecycleAction.schedule => 'Blitz scheduled successfully.',
    TeacherBlitzLifecycleAction.activate when reconciled => 'Blitz is active.',
    TeacherBlitzLifecycleAction.activate => switch (blitz.status) {
      TeacherBlitzStatus.closed =>
        'Activation was confirmed. This Blitz is now closed.',
      TeacherBlitzStatus.archived =>
        'Activation was confirmed. This Blitz is now archived.',
      _ => 'Blitz activated successfully.',
    },
    TeacherBlitzLifecycleAction.close => 'Blitz closed successfully.',
    TeacherBlitzLifecycleAction.archive => 'Blitz archived successfully.',
  };
}

String _definiteFailureMessage(
  TeacherBlitzLifecycleAction action,
  ApiFailure failure,
) {
  if (failure.statusCode == 422 &&
      failure.serverCode == ApiErrorCodes.validationFailed &&
      action == TeacherBlitzLifecycleAction.schedule) {
    return 'The server rejected this scheduled time.\nChoose a future time in '
        'the Institution timezone and try again.';
  }
  return switch (failure.serverCode) {
    ApiErrorCodes.forbidden =>
      'You do not have permission to change this Blitz.',
    ApiErrorCodes.validationFailed =>
      'The Blitz lifecycle change could not be validated. Refresh and review '
          'the current state.',
    ApiErrorCodes.rateLimited => 'Too many requests. Wait before trying again.',
    _ => 'The Blitz lifecycle action could not be completed.',
  };
}

String _conflictMessage(
  TeacherBlitzLifecycleAction action,
  String? code,
  AppDeviceSurface surface,
) {
  // Mobile has no Question or assignment editor to point to.
  if (surface == AppDeviceSurface.mobile) {
    switch (code) {
      case ApiErrorCodes.assessmentHasNoScoreablePoints:
        return 'This Blitz needs at least one scoreable Question.\nUse the '
            'desktop Teacher workspace to manage Questions.';
      case ApiErrorCodes.assessmentNotAssigned:
        return 'The server could not establish a valid assigned Student set.'
            '\nUse the desktop Teacher workspace to review the assignment '
            'when editing is required.';
    }
  }
  return switch ((action, code)) {
    (_, ApiErrorCodes.taskClosed) => 'This Blitz is closed.',
    (_, ApiErrorCodes.taskArchived) => 'This Blitz is archived.',
    (TeacherBlitzLifecycleAction.schedule, ApiErrorCodes.topicNotEditable) =>
      'The Topic is no longer editable.',
    (TeacherBlitzLifecycleAction.schedule, ApiErrorCodes.businessConflict) =>
      'Scheduling is not available in the current server state.\nRefresh the '
          'Blitz before trying again.',
    (
      TeacherBlitzLifecycleAction.activate,
      ApiErrorCodes.institutionSettingsIncomplete,
    ) =>
      "The Institution's Blitz timer-start setting is not configured.\nAsk the "
          'Institution Admin to complete the Blitz timer setting before '
          'activation.',
    (
      TeacherBlitzLifecycleAction.activate,
      ApiErrorCodes.assessmentHasNoScoreablePoints,
    ) =>
      'This Blitz needs at least one scoreable Question before activation.\n'
          'Review the Questions and points.',
    (
      TeacherBlitzLifecycleAction.activate,
      ApiErrorCodes.assessmentNotAssigned,
    ) =>
      'The server could not establish a valid assigned Student set.\nReview '
          'the Blitz assignment or current Group membership.',
    (
      TeacherBlitzLifecycleAction.activate,
      ApiErrorCodes.officialCohortMismatch,
    ) =>
      "The official Blitz cohort does not match the Topic's established "
          'official cohort.\nRefresh the official pair and Blitz before '
          'continuing.',
    (
      TeacherBlitzLifecycleAction.activate,
      ApiErrorCodes.idempotencyKeyReused,
    ) =>
      'The activation request could not be safely replayed.\nRefresh the '
          'Blitz before starting another activation.',
    (TeacherBlitzLifecycleAction.activate, ApiErrorCodes.topicNotEditable) =>
      'The Topic is not in a state that allows this Blitz to be activated.\n'
          'Review the current Topic.',
    (TeacherBlitzLifecycleAction.activate, ApiErrorCodes.businessConflict) =>
      'The Blitz cannot be activated in the current server state.\nRefresh and '
          'review its configuration.',
    (TeacherBlitzLifecycleAction.close, ApiErrorCodes.taskNotActive) =>
      'This Blitz is no longer active.',
    (TeacherBlitzLifecycleAction.close, ApiErrorCodes.topicNotEditable) =>
      'The Topic is no longer available for this action.',
    (TeacherBlitzLifecycleAction.close, ApiErrorCodes.businessConflict) =>
      'This Blitz cannot be closed in the current server state.\nReview the '
          'current Blitz before trying again.',
    (TeacherBlitzLifecycleAction.archive, ApiErrorCodes.businessConflict) =>
      'This Blitz cannot be archived in the current server state.\nRefresh the '
          'Blitz and official pair before trying again.',
    _ => 'The Blitz lifecycle action could not be completed.',
  };
}
