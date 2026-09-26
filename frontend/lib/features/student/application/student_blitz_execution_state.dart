import '../../../core/network/api_failure.dart';
import '../domain/student_blitz.dart';
import '../domain/student_blitz_attempt.dart';
import 'student_attempt_publication_token.dart';

enum StudentBlitzExecutionStatus {
  /// No execution Attempt is owned by this route session.
  none,

  /// The in-progress Attempt is the current publication.
  active,

  /// A completed Start request replay is requested or in flight.
  refreshing,

  /// The Attempt is finalized; everything is read-only.
  terminal,

  /// The last replay could not confirm the current Attempt.
  reconciliationFailed,
}

/// Result of one completed Start request replay.
enum StudentBlitzAttemptReplayOutcome {
  /// The same Attempt is still in progress; its full state was adopted.
  active,

  /// The same Attempt is finalized; its full state was adopted.
  terminal,

  /// The replay could not confirm the current state; nothing was adopted.
  failed,

  /// No replay authority exists, or the server no longer serves this
  /// Attempt and the execution was dropped.
  unavailable,
}

class StudentBlitzExecutionState {
  const StudentBlitzExecutionState({
    this.status = StudentBlitzExecutionStatus.none,
    this.attempt,
    this.publicationToken,
    this.failure,
    this.localTimeExpired = false,
    this.countdownAnchor,
    this.blitzTitle,
    this.confirmedBySubmit = false,
  });

  final StudentBlitzExecutionStatus status;

  /// The only frontend copy of the current execution Attempt.
  final StudentBlitzAttempt? attempt;
  final StudentAttemptPublicationToken? publicationToken;

  /// Why the last replay could not confirm the Attempt.
  final ApiFailure? failure;

  /// The local countdown reached zero (or the server reported the time as
  /// expired). New writes stay blocked until a newer in-progress Attempt
  /// with positive server-anchored time is adopted.
  final bool localTimeExpired;

  /// The latest server timing snapshot anchoring the execution countdown.
  final StudentBlitzCountdownAnchor? countdownAnchor;
  final String? blitzTitle;

  /// The terminal Attempt was adopted from this route session's own Submit
  /// success rather than from a replay.
  final bool confirmedBySubmit;

  /// An in-progress Attempt is shown, whatever its reconciliation state.
  bool get isExecuting =>
      attempt?.status == StudentBlitzAttemptStatus.inProgress &&
      (status == StudentBlitzExecutionStatus.active ||
          status == StudentBlitzExecutionStatus.refreshing ||
          status == StudentBlitzExecutionStatus.reconciliationFailed);

  bool get isTerminal =>
      status == StudentBlitzExecutionStatus.terminal && attempt != null;

  /// New answer, file and Submit writes may begin.
  bool get acceptsWrites =>
      status == StudentBlitzExecutionStatus.active &&
      attempt?.status == StudentBlitzAttemptStatus.inProgress &&
      !localTimeExpired;

  StudentBlitzExecutionState copyWith({
    StudentBlitzExecutionStatus? status,
    StudentBlitzAttempt? attempt,
    StudentAttemptPublicationToken? publicationToken,
    Object? failure = _unchanged,
    bool? localTimeExpired,
    StudentBlitzCountdownAnchor? countdownAnchor,
  }) => StudentBlitzExecutionState(
    status: status ?? this.status,
    attempt: attempt ?? this.attempt,
    publicationToken: publicationToken ?? this.publicationToken,
    failure: identical(failure, _unchanged)
        ? this.failure
        : failure as ApiFailure?,
    localTimeExpired: localTimeExpired ?? this.localTimeExpired,
    countdownAnchor: countdownAnchor ?? this.countdownAnchor,
    blitzTitle: blitzTitle,
    confirmedBySubmit: confirmedBySubmit,
  );
}

const _unchanged = Object();
