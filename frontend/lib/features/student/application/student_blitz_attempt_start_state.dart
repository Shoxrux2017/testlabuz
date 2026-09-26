import '../../../core/network/api_failure.dart';
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

/// The request lifecycle of one explicit Start/Resume/replacement Start. The
/// returned Attempt itself is owned by the execution controller.
class StudentBlitzAttemptStartState {
  const StudentBlitzAttemptStartState({
    this.status = StudentBlitzAttemptStartStatus.idle,
    this.resultKind,
    this.failure,
    this.feedback,
    this.originatingIntent,
    this.requestedAttemptId,
  });

  /// `active`/`terminal` after a success handed its Attempt to execution.
  final StudentBlitzAttemptStartStatus status;
  final StudentBlitzAttemptStartResultKind? resultKind;
  final ApiFailure? failure;
  final StudentBlitzStartFeedback? feedback;
  final StudentBlitzAttemptIntent? originatingIntent;
  final String? requestedAttemptId;

  /// Only these states may begin a new logical Start/Resume.
  bool get acceptsNewRequest =>
      status == StudentBlitzAttemptStartStatus.idle ||
      status == StudentBlitzAttemptStartStatus.failure ||
      status == StudentBlitzAttemptStartStatus.terminal;

  StudentBlitzAttemptStartState withStatus(
    StudentBlitzAttemptStartStatus status,
  ) => StudentBlitzAttemptStartState(
    status: status,
    resultKind: resultKind,
    failure: failure,
    originatingIntent: originatingIntent,
    requestedAttemptId: requestedAttemptId,
  );

  StudentBlitzAttemptStartState withoutFeedback() => withStatus(status);
}
