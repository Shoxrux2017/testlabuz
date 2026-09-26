import '../domain/teacher_blitz_lifecycle.dart';

enum TeacherBlitzLifecycleStatus {
  idle,
  submitting,
  reconciling,
  confirmedSuccess,
  definiteFailure,
  outcomeReview,
  unavailable,
}

/// Lifecycle operation status; the FE-001 detail stays the Blitz authority.
class TeacherBlitzLifecycleState {
  const TeacherBlitzLifecycleState({
    this.status = TeacherBlitzLifecycleStatus.idle,
    this.action,
    this.feedback,
    this.notice,
    this.conflictCode,
    this.requiresCheckCurrent = false,
    this.canRetryActivation = false,
  });

  final TeacherBlitzLifecycleStatus status;
  final TeacherBlitzLifecycleAction? action;

  /// One-shot route feedback, used for confirmed success.
  final String? feedback;

  /// Persistent safe review/failure text for the lifecycle controls.
  final String? notice;
  final String? conflictCode;

  /// The outcome could not be read, so the route stays blocked until checked.
  final bool requiresCheckCurrent;

  /// An unresolved activation keeps its Idempotency-Key for an explicit Retry.
  final bool canRetryActivation;

  bool get isBusy =>
      status == TeacherBlitzLifecycleStatus.submitting ||
      status == TeacherBlitzLifecycleStatus.reconciling;

  bool get canCheckCurrent =>
      status == TeacherBlitzLifecycleStatus.outcomeReview && action != null;

  bool get hasBlockingOutcome => canCheckCurrent && requiresCheckCurrent;

  bool get blocksMutations => isBusy || hasBlockingOutcome;

  TeacherBlitzLifecycleState withoutFeedback() {
    return TeacherBlitzLifecycleState(
      status: status,
      action: action,
      notice: notice,
      conflictCode: conflictCode,
      requiresCheckCurrent: requiresCheckCurrent,
      canRetryActivation: canRetryActivation,
    );
  }

  TeacherBlitzLifecycleState withRetryAvailability(bool available) {
    return TeacherBlitzLifecycleState(
      status: status,
      action: action,
      feedback: feedback,
      notice: notice,
      conflictCode: conflictCode,
      requiresCheckCurrent: requiresCheckCurrent,
      canRetryActivation: available,
    );
  }
}
