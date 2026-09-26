import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../../core/network/idempotency_key_generator.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_blitz_attempt_repository_impl.dart';
import '../domain/student_blitz.dart';
import '../domain/student_blitz_attempt.dart';
import '../domain/student_blitz_route_target.dart';
import 'student_active_blitz_controller.dart';
import 'student_blitz_attempt_start_state.dart';
import 'student_blitz_detail_controller.dart';
import 'student_blitz_detail_state.dart';
import 'student_session_key.dart';

final studentBlitzAttemptStartControllerProvider = NotifierProvider.autoDispose
    .family<
      StudentBlitzAttemptStartController,
      StudentBlitzAttemptStartState,
      StudentBlitzRouteTarget
    >(StudentBlitzAttemptStartController.new);

/// Owns one route session's explicit Start/Resume/replacement Start and the
/// in-memory execution Attempt returned by it. There is no Attempt read API,
/// so leaving the route drops the shell and a later Resume re-requests it.
class StudentBlitzAttemptStartController
    extends Notifier<StudentBlitzAttemptStartState> {
  StudentBlitzAttemptStartController(this.target);

  final StudentBlitzRouteTarget target;
  StudentSessionKey? _activeSessionKey;

  /// The frozen logical request an uncertain Retry resends unchanged.
  StudentBlitzAttemptRequest? _pendingRequest;
  StudentBlitzTimerMode? _pendingMode;
  String? _pendingTitle;
  var _generation = 0;

  @override
  StudentBlitzAttemptStartState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (key == null) {
      _clearOwnership();
      return const StudentBlitzAttemptStartState();
    }
    ref.listen(studentBlitzDetailControllerProvider(target), _onDetail);
    if (_activeSessionKey == key) {
      return state;
    }
    _clearOwnership();
    _activeSessionKey = key;
    return const StudentBlitzAttemptStartState();
  }

  /// Begins one new logical execution request for [action], only when the
  /// current confirmed detail still projects exactly that action.
  Future<void> start(StudentBlitzExecutionAction action) async {
    final key = _activeSessionKey;
    if (key == null || !_matchesSession(key) || !state.acceptsNewRequest) {
      return;
    }
    final blitz = ref
        .read(studentBlitzDetailControllerProvider(target))
        .confirmedBlitz;
    if (blitz == null ||
        blitz.id.toLowerCase() != target.blitzId ||
        blitz.topic.id.toLowerCase() != target.topicId ||
        studentBlitzExecutionAction(blitz.attempts) != action) {
      return;
    }
    final idempotencyKey = ref.read(idempotencyKeyGeneratorProvider).generate();
    _pendingRequest = switch (action) {
      StudentBlitzExecutionAction.startNormal =>
        StudentBlitzAttemptRequest.startNormal(idempotencyKey: idempotencyKey),
      // The exact Attempt confirmed now; a later detail can never rewrite it.
      StudentBlitzExecutionAction.resume => StudentBlitzAttemptRequest.resume(
        attemptId: blitz.attempts.inProgressAttemptId!,
        idempotencyKey: idempotencyKey,
      ),
      StudentBlitzExecutionAction.startReplacement =>
        StudentBlitzAttemptRequest.startReplacement(
          idempotencyKey: idempotencyKey,
        ),
    };
    _pendingMode = blitz.timing.mode;
    _pendingTitle = blitz.title;
    await _submit(key);
  }

  /// Resends the same intent, Attempt ID and key after an uncertain outcome.
  Future<void> retry() async {
    final key = _activeSessionKey;
    if (key != null &&
        _matchesSession(key) &&
        state.status == StudentBlitzAttemptStartStatus.uncertain &&
        _pendingRequest != null) {
      await _submit(key);
    }
  }

  StudentBlitzStartFeedback? consumeFeedback() {
    final feedback = state.feedback;
    if (feedback != null) {
      state = state.withoutFeedback();
    }
    return feedback;
  }

  /// The execution countdown for [anchor] reached zero locally. Execution
  /// becomes read-only and one authoritative detail read decides the state;
  /// nothing is finalized on the device.
  void markExecutionExpired(StudentBlitzCountdownAnchor anchor) {
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        state.status != StudentBlitzAttemptStartStatus.active ||
        state.executionAnchor != anchor ||
        state.isReconcilingExpiry) {
      return;
    }
    state = state.reconcilingExpiry();
    ref
        .read(studentBlitzDetailControllerProvider(target).notifier)
        .reconcileAfterLocalExpiry();
  }

  Future<void> _submit(StudentSessionKey key) async {
    final request = _pendingRequest!;
    final generation = ++_generation;
    final requestTarget = target;
    state = StudentBlitzAttemptStartState(
      status: StudentBlitzAttemptStartStatus.submitting,
      originatingIntent: request.intent,
      requestedAttemptId: request.attemptId,
      blitzTitle: _pendingTitle,
    );
    try {
      final result = await ref
          .read(studentBlitzAttemptRepositoryProvider)
          .start(requestTarget.blitzId, request);
      if (!_canPublish(generation, key, requestTarget)) {
        return;
      }
      if (!isAcceptedStudentBlitzStartResult(
        request: request,
        blitzId: requestTarget.blitzId,
        result: result,
        expectedMode: _pendingMode,
      )) {
        throw ApiRequestException(
          ApiFailure.local(
            kind: ApiFailureKind.invalidResponse,
            message: 'The Blitz attempt response could not be confirmed.',
          ),
        );
      }
      _pendingRequest = null;
      final attempt = result.attempt;
      final inProgress = attempt.status == StudentBlitzAttemptStatus.inProgress;
      state = StudentBlitzAttemptStartState(
        status: inProgress
            ? StudentBlitzAttemptStartStatus.active
            : StudentBlitzAttemptStartStatus.terminal,
        attempt: attempt,
        resultKind: result.resultKind,
        feedback: inProgress ? _successFeedback(request.intent, result) : null,
        originatingIntent: request.intent,
        requestedAttemptId: request.attemptId,
        blitzTitle: _pendingTitle,
        executionAnchor: inProgress
            ? StudentBlitzCountdownAnchor(
                subjectId: attempt.id.toLowerCase(),
                deadlineAt: attempt.deadlineAt,
                serverNow: attempt.timing.serverNow,
                remainingSeconds: attempt.timing.remainingSeconds,
              )
            : null,
      );
      _reconcile(key);
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key, requestTarget) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      final failure = exception.failure;
      if (_isUncertain(failure)) {
        _publishUncertain(request, failure);
        return;
      }
      _pendingRequest = null;
      state = StudentBlitzAttemptStartState(
        status: StudentBlitzAttemptStartStatus.failure,
        failure: failure,
        originatingIntent: request.intent,
        requestedAttemptId: request.attemptId,
      );
      // Reconciliation shows the newly authoritative action, if any; it never
      // starts one, so a stale Resume cannot become a replacement Start.
      if (_reconciledCodes.contains(failure.serverCode)) {
        _reconcile(key);
      }
    } catch (_) {
      // The POST may have committed, so keep the frozen request for a
      // same-key Retry rather than a new logical Start.
      if (_canPublish(generation, key, requestTarget)) {
        _publishUncertain(
          request,
          ApiFailure.local(
            kind: ApiFailureKind.unknown,
            message: 'Unexpected Blitz attempt failure.',
          ),
        );
      }
    }
  }

  void _publishUncertain(
    StudentBlitzAttemptRequest request,
    ApiFailure failure,
  ) {
    state = StudentBlitzAttemptStartState(
      status: StudentBlitzAttemptStartStatus.uncertain,
      failure: failure,
      originatingIntent: request.intent,
      requestedAttemptId: request.attemptId,
      blitzTitle: _pendingTitle,
    );
  }

  void _onDetail(StudentBlitzDetailState? _, StudentBlitzDetailState next) {
    final attempt = state.attempt;
    if (state.status != StudentBlitzAttemptStartStatus.active ||
        attempt == null) {
      return;
    }
    switch (next.status) {
      case StudentBlitzDetailStatus.notActive ||
          StudentBlitzDetailStatus.timeExpired ||
          StudentBlitzDetailStatus.notFound:
        _retireExecution();
      case StudentBlitzDetailStatus.data:
        final blitz = next.blitz!;
        final attemptId = attempt.id.toLowerCase();
        if (blitz.attempts.inProgressAttemptId?.toLowerCase() != attemptId) {
          _retireExecution();
          return;
        }
        final deadline = blitz.timing.deadlineAt;
        final remaining = blitz.timing.remainingSeconds;
        if (deadline == null ||
            remaining == null ||
            remaining <= 0 ||
            !deadline.isAtSameMomentAs(attempt.deadlineAt)) {
          return;
        }
        final anchor = StudentBlitzCountdownAnchor(
          subjectId: attemptId,
          deadlineAt: deadline,
          serverNow: blitz.timing.serverNow,
          remainingSeconds: remaining,
        );
        if (anchor != state.executionAnchor) {
          state = state.withExecutionAnchor(anchor);
        }
      case StudentBlitzDetailStatus.initial ||
          StudentBlitzDetailStatus.loading ||
          StudentBlitzDetailStatus.refreshing ||
          StudentBlitzDetailStatus.error:
        return;
    }
  }

  /// The server no longer confirms this execution; its Questions are dropped
  /// and only an explicit Resume can show an execution again.
  void _retireExecution() {
    state = const StudentBlitzAttemptStartState();
  }

  void _reconcile(StudentSessionKey key) {
    ref.read(studentBlitzDetailControllerProvider(target).notifier).reconcile();
    if (ref.exists(studentActiveBlitzControllerProvider)) {
      ref
          .read(studentActiveBlitzControllerProvider.notifier)
          .refreshAfterExecution(key);
    }
  }

  StudentBlitzStartFeedback _successFeedback(
    StudentBlitzAttemptIntent intent,
    StudentBlitzAttemptStartResult result,
  ) {
    if (result.resultKind == StudentBlitzAttemptStartResultKind.created) {
      return result.attempt.attemptNumber == 2
          ? StudentBlitzStartFeedback.additionalStarted
          : StudentBlitzStartFeedback.started;
    }
    return intent == StudentBlitzAttemptIntent.startReplacement
        ? StudentBlitzStartFeedback.additionalAlreadyInProgress
        : StudentBlitzStartFeedback.resumed;
  }

  static const _reconciledCodes = {
    ApiErrorCodes.blitzNotActive,
    ApiErrorCodes.blitzTimeExpired,
    ApiErrorCodes.attemptNotEditable,
    ApiErrorCodes.attemptsExhausted,
    ApiErrorCodes.assessmentNotAssigned,
    ApiErrorCodes.resourceNotFound,
    ApiErrorCodes.businessConflict,
  };

  bool _isUncertain(ApiFailure failure) => switch (failure.kind) {
    ApiFailureKind.connection ||
    ApiFailureKind.timeout ||
    ApiFailureKind.cancelled ||
    ApiFailureKind.invalidResponse ||
    ApiFailureKind.unknown => true,
    ApiFailureKind.server || ApiFailureKind.validation =>
      failure.statusCode == null ||
          failure.statusCode! < 400 ||
          failure.statusCode! >= 500,
  };

  bool _canPublish(
    int generation,
    StudentSessionKey key,
    StudentBlitzRouteTarget requestTarget,
  ) =>
      ref.mounted &&
      generation == _generation &&
      target == requestTarget &&
      _matchesSession(key);

  bool _matchesSession(StudentSessionKey key) =>
      ref.mounted &&
      _activeSessionKey == key &&
      StudentSessionSnapshot.fromSession(
            ref.read(authSessionControllerProvider),
            ref.read(appDeviceSurfaceProvider),
          ).eligibleKey ==
          key;

  bool _clearForSessionFailure(ApiFailure failure) {
    final code = failure.serverCode;
    if (code != ApiErrorCodes.authenticationRequired &&
        code != ApiErrorCodes.passwordChangeRequired &&
        code != ApiErrorCodes.userInactive &&
        code != ApiErrorCodes.institutionInactive) {
      return false;
    }
    _clearOwnership();
    state = const StudentBlitzAttemptStartState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _pendingRequest = null;
    _pendingMode = null;
    _pendingTitle = null;
    _generation += 1;
  }
}
