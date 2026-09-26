import '../../../core/network/api_failure.dart';
import '../domain/student_blitz.dart';
import '../domain/student_blitz_attempt.dart';

enum StudentBlitzAttemptStartStatus {
  idle,
  submitting,
  uncertain,
  active,
  terminal,
  failure,
}

/// Presentation-only confirmation of a validated Start/Resume success.
enum StudentBlitzStartFeedback {
  started,
  resumed,
  additionalStarted,
  additionalAlreadyInProgress,
}

class StudentBlitzAttemptStartState {
  const StudentBlitzAttemptStartState({
    this.status = StudentBlitzAttemptStartStatus.idle,
    this.attempt,
    this.resultKind,
    this.failure,
    this.feedback,
    this.originatingIntent,
    this.requestedAttemptId,
    this.blitzTitle,
    this.executionAnchor,
    this.isReconcilingExpiry = false,
  });

  final StudentBlitzAttemptStartStatus status;

  /// The server Attempt; its Questions exist only after a validated success.
  final StudentBlitzAttempt? attempt;
  final StudentBlitzAttemptStartResultKind? resultKind;
  final ApiFailure? failure;
  final StudentBlitzStartFeedback? feedback;
  final StudentBlitzAttemptIntent? originatingIntent;
  final String? requestedAttemptId;
  final String? blitzTitle;

  /// Latest authoritative snapshot anchoring the execution countdown.
  final StudentBlitzCountdownAnchor? executionAnchor;

  /// The local countdown reached zero; execution stays read-only until the
  /// server confirms the current state.
  final bool isReconcilingExpiry;

  /// Only these states may begin a new logical Start/Resume.
  bool get acceptsNewRequest =>
      status == StudentBlitzAttemptStartStatus.idle ||
      status == StudentBlitzAttemptStartStatus.failure ||
      status == StudentBlitzAttemptStartStatus.terminal;

  StudentBlitzAttemptStartState withExecutionAnchor(
    StudentBlitzCountdownAnchor anchor,
  ) => _copy(executionAnchor: anchor, isReconcilingExpiry: false);

  StudentBlitzAttemptStartState reconcilingExpiry() =>
      _copy(executionAnchor: executionAnchor, isReconcilingExpiry: true);

  StudentBlitzAttemptStartState withoutFeedback() => _copy(
    executionAnchor: executionAnchor,
    isReconcilingExpiry: isReconcilingExpiry,
    clearFeedback: true,
  );

  StudentBlitzAttemptStartState _copy({
    required StudentBlitzCountdownAnchor? executionAnchor,
    required bool isReconcilingExpiry,
    bool clearFeedback = false,
  }) => StudentBlitzAttemptStartState(
    status: status,
    attempt: attempt,
    resultKind: resultKind,
    failure: failure,
    feedback: clearFeedback ? null : feedback,
    originatingIntent: originatingIntent,
    requestedAttemptId: requestedAttemptId,
    blitzTitle: blitzTitle,
    executionAnchor: executionAnchor,
    isReconcilingExpiry: isReconcilingExpiry,
  );
}
