import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_request_exception.dart';
import '../../auth/application/auth_session_controller.dart';
import '../data/student_blitz_attempt_repository_impl.dart';
import '../domain/student_answer_mutation.dart';
import '../domain/student_attempt_answer.dart';
import '../domain/student_blitz.dart';
import '../domain/student_blitz_attempt.dart';
import '../domain/student_blitz_route_target.dart';
import 'student_active_blitz_controller.dart';
import 'student_attempt_publication_token.dart';
import 'student_blitz_detail_controller.dart';
import 'student_blitz_detail_state.dart';
import 'student_blitz_execution_state.dart';
import 'student_session_key.dart';

final studentBlitzExecutionControllerProvider = NotifierProvider.autoDispose
    .family<
      StudentBlitzExecutionController,
      StudentBlitzExecutionState,
      StudentBlitzRouteTarget
    >(StudentBlitzExecutionController.new);

/// The single route-session owner of the current Blitz execution Attempt.
///
/// There is no Blitz Attempt read API. The exact Start/Resume/replacement
/// request that produced the Attempt is kept privately, and replaying it
/// unchanged (same intent, Attempt ID and key) is the only way to re-read the
/// current Attempt. A replay never creates work: the key is already
/// completed, so the server returns the same Attempt's current state.
class StudentBlitzExecutionController
    extends Notifier<StudentBlitzExecutionState> {
  StudentBlitzExecutionController(this.target);

  final StudentBlitzRouteTarget target;
  StudentSessionKey? _activeSessionKey;

  /// The request actually sent by the validated Start success; replayed as is.
  StudentBlitzAttemptRequest? _completedStartRequest;
  var _generation = 0;

  /// Answer, file and Submit requests in flight (Section 91 of FE-005).
  final _writes = <Object>{};
  Completer<StudentBlitzAttemptReplayOutcome>? _replay;
  var _replayStarted = false;
  var _refreshDetailAfterReplay = false;

  @override
  StudentBlitzExecutionState build() {
    final key = StudentSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey;
    if (key == null) {
      _clearOwnership();
      return const StudentBlitzExecutionState();
    }
    ref.listen(studentBlitzDetailControllerProvider(target), _onDetail);
    if (_activeSessionKey == key) {
      return state;
    }
    _clearOwnership();
    _activeSessionKey = key;
    return const StudentBlitzExecutionState();
  }

  /// Adopts a validated Start/Resume/replacement-Start success together with
  /// the exact request that produced it, in one step.
  bool acceptStartedAttempt(
    StudentBlitzAttempt attempt,
    StudentBlitzAttemptRequest request, {
    String? blitzTitle,
  }) {
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        !_belongsToRequest(attempt, request)) {
      return false;
    }
    _resetOperations();
    _completedStartRequest = request;
    _publish(attempt, blitzTitle: blitzTitle, fresh: true);
    return true;
  }

  /// Replays the completed Start request to re-read the current Attempt.
  ///
  /// Concurrent callers share one replay, and a replay never runs while an
  /// answer, file or Submit request is still in flight.
  Future<StudentBlitzAttemptReplayOutcome> refreshCurrentAttempt() =>
      _requestReplay(refreshDetail: false);

  /// A write was rejected because the server state moved on. Writes stop and
  /// the current Attempt is re-read; the request is never retried.
  Future<StudentBlitzAttemptReplayOutcome> reconcileAfterRejectedWrite(
    ApiFailure failure,
  ) {
    final timeExpired = failure.serverCode == ApiErrorCodes.blitzTimeExpired;
    if (timeExpired && state.isExecuting && !state.localTimeExpired) {
      state = state.copyWith(localTimeExpired: true);
    }
    return _requestReplay(
      refreshDetail:
          timeExpired ||
          failure.serverCode == ApiErrorCodes.blitzNotActive ||
          failure.serverCode == ApiErrorCodes.resourceNotFound,
    );
  }

  /// The execution countdown for [anchor] reached zero on this device. Writes
  /// stop at once and the server decides the outcome; nothing is finalized
  /// locally and no dirty draft is saved.
  void markLocalTimeExpired(StudentBlitzCountdownAnchor anchor) {
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        !state.isExecuting ||
        state.localTimeExpired ||
        state.countdownAnchor != anchor) {
      return;
    }
    state = state.copyWith(localTimeExpired: true);
    unawaited(_requestReplay(refreshDetail: true));
  }

  /// A server-confirmed PUT for one Question patches exactly that answer.
  bool acceptAnswerMutation({
    required String attemptId,
    required String questionId,
    required StudentAttemptAnswerMutationResult result,
    required StudentAttemptPublicationToken? expectedPublication,
  }) {
    final key = _activeSessionKey;
    final attempt = state.attempt;
    final id = questionId.toLowerCase();
    if (key == null ||
        !_matchesSession(key) ||
        !_acceptsServerWrite ||
        attempt == null ||
        attempt.status != StudentBlitzAttemptStatus.inProgress ||
        attempt.id.toLowerCase() != attemptId.toLowerCase() ||
        expectedPublication == null ||
        !identical(expectedPublication, state.publicationToken) ||
        result.questionId.toLowerCase() != id ||
        (result.answer == null) != (result.updatedAt == null)) {
      return false;
    }
    final questions = attempt.questions.where(
      (question) => question.id.toLowerCase() == id,
    );
    if (questions.length != 1 || questions.single.type != result.type) {
      return false;
    }
    final answer = result.answer;
    final answers = [
      for (final existing in attempt.answers)
        if (existing.questionId.toLowerCase() != id) existing,
      if (answer != null)
        StudentAttemptAnswerState(
          questionId: questions.single.id,
          type: result.type,
          value: answer,
          updatedAt: result.updatedAt!,
        ),
    ];
    state = StudentBlitzExecutionState(
      status: state.status,
      attempt: _withAnswers(attempt, answers),
      publicationToken: StudentAttemptPublicationToken(),
      localTimeExpired: state.localTimeExpired,
      countdownAnchor: state.countdownAnchor,
      blitzTitle: state.blitzTitle,
    );
    return true;
  }

  /// Adopts the terminal Attempt returned by this route session's own Submit.
  bool acceptSubmittedAttempt(StudentBlitzAttempt attempt) {
    final key = _activeSessionKey;
    final current = state.attempt;
    if (key == null ||
        !_matchesSession(key) ||
        current == null ||
        current.status != StudentBlitzAttemptStatus.inProgress ||
        !(_acceptsServerWrite ||
            state.status == StudentBlitzExecutionStatus.reconciliationFailed) ||
        attempt.status == StudentBlitzAttemptStatus.inProgress ||
        !_isSameAttempt(attempt, current)) {
      return false;
    }
    _publish(attempt, confirmedBySubmit: true);
    _reconcileDetailAndList(key);
    return true;
  }

  /// A Submit rejection showed that the server and this Attempt disagree.
  /// Execution stays read-only until an explicit check confirms it again.
  void requireReconciliation(ApiFailure failure) {
    if (state.isExecuting && _replay == null) {
      state = state.copyWith(
        status: StudentBlitzExecutionStatus.reconciliationFailed,
        failure: failure,
      );
    }
  }

  /// Registers one answer, file or Submit request; `null` while a replay is
  /// requested, because a write never competes with authority recovery.
  Object? beginWrite() {
    if (_replay != null) {
      return null;
    }
    final write = Object();
    _writes.add(write);
    return write;
  }

  void endWrite(Object write) {
    if (!_writes.remove(write) || _writes.isNotEmpty) {
      return;
    }
    final replay = _replay;
    if (replay != null && !_replayStarted) {
      unawaited(_runReplay(replay));
    }
  }

  /// Leaving discards the local execution and its replay authority. The
  /// server Attempt and its timer are unaffected.
  void clearLocalState() {
    final session = _activeSessionKey;
    _clearOwnership();
    _activeSessionKey = session;
    state = const StudentBlitzExecutionState();
  }

  /// Server writes may be adopted while no replay has been sent yet; once the
  /// replay is on the wire its result alone is authoritative.
  bool get _acceptsServerWrite =>
      state.status == StudentBlitzExecutionStatus.active ||
      (state.status == StudentBlitzExecutionStatus.refreshing &&
          !_replayStarted);

  Future<StudentBlitzAttemptReplayOutcome> _requestReplay({
    required bool refreshDetail,
  }) {
    final key = _activeSessionKey;
    if (key == null ||
        !_matchesSession(key) ||
        _completedStartRequest == null ||
        !state.isExecuting) {
      return Future.value(StudentBlitzAttemptReplayOutcome.unavailable);
    }
    _refreshDetailAfterReplay = _refreshDetailAfterReplay || refreshDetail;
    final pending = _replay;
    if (pending != null) {
      return pending.future;
    }
    final replay = Completer<StudentBlitzAttemptReplayOutcome>();
    _replay = replay;
    state = state.copyWith(status: StudentBlitzExecutionStatus.refreshing);
    if (_writes.isEmpty) {
      unawaited(_runReplay(replay));
    }
    return replay.future;
  }

  Future<void> _runReplay(
    Completer<StudentBlitzAttemptReplayOutcome> replay,
  ) async {
    final key = _activeSessionKey;
    final request = _completedStartRequest;
    final current = state.attempt;
    if (state.isTerminal) {
      // The in-flight write (a Submit) already produced the terminal Attempt.
      _finishReplay(replay, StudentBlitzAttemptReplayOutcome.terminal);
      return;
    }
    if (key == null || request == null || current == null) {
      _finishReplay(replay, StudentBlitzAttemptReplayOutcome.unavailable);
      return;
    }
    _replayStarted = true;
    final generation = _generation;
    StudentBlitzAttemptReplayOutcome outcome;
    try {
      final result = await ref
          .read(studentBlitzAttemptRepositoryProvider)
          .start(target.blitzId, request);
      if (!_canPublish(generation, key)) {
        return;
      }
      if (!_isReplayOf(result, request, current)) {
        _retire();
        outcome = StudentBlitzAttemptReplayOutcome.unavailable;
      } else {
        _publish(result.attempt);
        outcome = state.isTerminal
            ? StudentBlitzAttemptReplayOutcome.terminal
            : StudentBlitzAttemptReplayOutcome.active;
      }
    } on ApiRequestException catch (exception) {
      if (!_canPublish(generation, key) ||
          _clearForSessionFailure(exception.failure)) {
        return;
      }
      outcome = _replayFailure(exception.failure);
    } catch (_) {
      if (!_canPublish(generation, key)) {
        return;
      }
      outcome = _replayFailure(
        ApiFailure.local(
          kind: ApiFailureKind.unknown,
          message: 'Unexpected Blitz attempt check failure.',
        ),
      );
    } finally {
      // An abandoned replay still answers its waiters.
      if (!replay.isCompleted && !identical(_replay, replay)) {
        replay.complete(StudentBlitzAttemptReplayOutcome.unavailable);
      }
    }
    final refreshDetail = _refreshDetailAfterReplay;
    _finishReplay(replay, outcome);
    // A finalized or dropped execution leaves detail as the only view, so
    // it must not keep offering a Resume the server no longer allows.
    if (outcome == StudentBlitzAttemptReplayOutcome.terminal ||
        outcome == StudentBlitzAttemptReplayOutcome.unavailable ||
        (refreshDetail && outcome == StudentBlitzAttemptReplayOutcome.active)) {
      _reconcileDetailAndList(key);
    }
  }

  StudentBlitzAttemptReplayOutcome _replayFailure(ApiFailure failure) {
    if (failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound) {
      _retire();
      return StudentBlitzAttemptReplayOutcome.unavailable;
    }
    state = state.copyWith(
      status: StudentBlitzExecutionStatus.reconciliationFailed,
      failure: failure,
    );
    return StudentBlitzAttemptReplayOutcome.failed;
  }

  void _finishReplay(
    Completer<StudentBlitzAttemptReplayOutcome> replay,
    StudentBlitzAttemptReplayOutcome outcome,
  ) {
    if (identical(_replay, replay)) {
      _replay = null;
      _replayStarted = false;
      _refreshDetailAfterReplay = false;
    }
    if (!replay.isCompleted) {
      replay.complete(outcome);
    }
  }

  void _onDetail(StudentBlitzDetailState? _, StudentBlitzDetailState next) {
    final attempt = state.attempt;
    if (state.status != StudentBlitzExecutionStatus.active ||
        attempt == null ||
        attempt.status != StudentBlitzAttemptStatus.inProgress) {
      return;
    }
    switch (next.status) {
      case StudentBlitzDetailStatus.notActive ||
          StudentBlitzDetailStatus.timeExpired ||
          StudentBlitzDetailStatus.notFound:
        _reconcileDetailConflict();
      case StudentBlitzDetailStatus.data:
        final blitz = next.blitz!;
        final attemptId = attempt.id.toLowerCase();
        if (blitz.attempts.inProgressAttemptId?.toLowerCase() != attemptId) {
          _reconcileDetailConflict();
          return;
        }
        final deadline = blitz.timing.deadlineAt;
        final remaining = blitz.timing.remainingSeconds;
        final current = state.countdownAnchor;
        // Only a newer server snapshot re-anchors; an older one would show
        // more time than the server has left.
        if (state.localTimeExpired ||
            deadline == null ||
            remaining == null ||
            remaining <= 0 ||
            !deadline.isAtSameMomentAs(attempt.deadlineAt) ||
            (current != null &&
                !blitz.timing.serverNow.isAfter(current.serverNow))) {
          return;
        }
        final anchor = StudentBlitzCountdownAnchor(
          subjectId: attemptId,
          deadlineAt: deadline,
          serverNow: blitz.timing.serverNow,
          remainingSeconds: remaining,
        );
        if (anchor != state.countdownAnchor) {
          state = state.copyWith(countdownAnchor: anchor);
        }
      case StudentBlitzDetailStatus.initial ||
          StudentBlitzDetailStatus.loading ||
          StudentBlitzDetailStatus.refreshing ||
          StudentBlitzDetailStatus.error:
        return;
    }
  }

  /// Detail no longer confirms this in-progress Attempt: a timeout or Teacher
  /// Close ends in the Attempt's own terminal state through the replay.
  void _reconcileDetailConflict() {
    if (_completedStartRequest == null) {
      _retire();
      return;
    }
    unawaited(_requestReplay(refreshDetail: false));
  }

  void _publish(
    StudentBlitzAttempt attempt, {
    String? blitzTitle,
    bool confirmedBySubmit = false,
    bool fresh = false,
  }) {
    final inProgress = attempt.status == StudentBlitzAttemptStatus.inProgress;
    final positive = inProgress && attempt.timing.remainingSeconds > 0;
    state = StudentBlitzExecutionState(
      status: inProgress
          ? StudentBlitzExecutionStatus.active
          : StudentBlitzExecutionStatus.terminal,
      attempt: attempt,
      publicationToken: StudentAttemptPublicationToken(),
      // Only positive server-anchored time can re-open writes.
      localTimeExpired:
          inProgress && !positive && (fresh ? false : state.localTimeExpired),
      countdownAnchor: inProgress
          ? StudentBlitzCountdownAnchor(
              subjectId: attempt.id.toLowerCase(),
              deadlineAt: attempt.deadlineAt,
              serverNow: attempt.timing.serverNow,
              remainingSeconds: attempt.timing.remainingSeconds,
            )
          : null,
      blitzTitle: blitzTitle ?? state.blitzTitle,
      confirmedBySubmit: confirmedBySubmit,
    );
  }

  /// The server no longer serves this Attempt to this route session.
  void _retire() {
    _generation += 1;
    _completedStartRequest = null;
    state = const StudentBlitzExecutionState();
  }

  bool _belongsToRequest(
    StudentBlitzAttempt attempt,
    StudentBlitzAttemptRequest request,
  ) {
    if (!isCanonicalStudentBlitzId(attempt.id) ||
        attempt.assessmentId.toLowerCase() != target.blitzId) {
      return false;
    }
    return switch (request.intent) {
      StudentBlitzAttemptIntent.startNormal =>
        request.attemptId == null && attempt.attemptNumber == 1,
      StudentBlitzAttemptIntent.startReplacement =>
        request.attemptId == null && attempt.attemptNumber == 2,
      StudentBlitzAttemptIntent.resume =>
        attempt.id.toLowerCase() == request.attemptId,
    };
  }

  bool _isReplayOf(
    StudentBlitzAttemptStartResult result,
    StudentBlitzAttemptRequest request,
    StudentBlitzAttempt current,
  ) =>
      _isSameAttempt(result.attempt, current) &&
      _belongsToRequest(result.attempt, request) &&
      isAcceptedStudentBlitzStartResult(
        request: request,
        blitzId: target.blitzId,
        result: result,
        expectedMode: current.timing.mode,
      );

  bool _isSameAttempt(
    StudentBlitzAttempt attempt,
    StudentBlitzAttempt current,
  ) =>
      attempt.id.toLowerCase() == current.id.toLowerCase() &&
      attempt.assessmentId.toLowerCase() == target.blitzId &&
      attempt.attemptNumber == current.attemptNumber;

  StudentBlitzAttempt _withAnswers(
    StudentBlitzAttempt attempt,
    List<StudentAttemptAnswerState> answers,
  ) => StudentBlitzAttempt(
    id: attempt.id,
    assessmentId: attempt.assessmentId,
    attemptNumber: attempt.attemptNumber,
    status: attempt.status,
    startedAt: attempt.startedAt,
    deadlineAt: attempt.deadlineAt,
    submittedAt: attempt.submittedAt,
    finalizedAt: attempt.finalizedAt,
    finalizationReason: attempt.finalizationReason,
    timing: attempt.timing,
    questions: attempt.questions,
    answers: answers,
  );

  void _reconcileDetailAndList(StudentSessionKey key) {
    ref.read(studentBlitzDetailControllerProvider(target).notifier).reconcile();
    if (ref.exists(studentActiveBlitzControllerProvider)) {
      ref
          .read(studentActiveBlitzControllerProvider.notifier)
          .refreshAfterExecution(key);
    }
  }

  bool _canPublish(int generation, StudentSessionKey key) =>
      ref.mounted && generation == _generation && _matchesSession(key);

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
    state = const StudentBlitzExecutionState();
    if (code != ApiErrorCodes.authenticationRequired) {
      unawaited(ref.read(authSessionControllerProvider.notifier).bootstrap());
    }
    return true;
  }

  void _resetOperations() {
    _generation += 1;
    _writes.clear();
    final replay = _replay;
    _replay = null;
    _replayStarted = false;
    _refreshDetailAfterReplay = false;
    if (replay != null && !replay.isCompleted) {
      replay.complete(StudentBlitzAttemptReplayOutcome.unavailable);
    }
  }

  void _clearOwnership() {
    _activeSessionKey = null;
    _completedStartRequest = null;
    _resetOperations();
  }
}
