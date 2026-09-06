import '../domain/teacher_homework_lifecycle.dart';

enum TeacherHomeworkLifecycleStatus {
  idle,
  submitting,
  reconciling,
  confirmedSuccess,
  definiteFailure,
  outcomeReview,
  unavailable,
}

class TeacherHomeworkLifecycleState {
  const TeacherHomeworkLifecycleState({
    this.status = TeacherHomeworkLifecycleStatus.idle,
    this.action,
    this.feedback,
    this.notice,
    this.conflictCode,
    this.requiresCheckCurrent = false,
  });

  final TeacherHomeworkLifecycleStatus status;
  final TeacherHomeworkLifecycleAction? action;

  /// One-shot route feedback, used for confirmed success.
  final String? feedback;

  /// Persistent safe review/failure text for the lifecycle controls.
  final String? notice;
  final String? conflictCode;
  final bool requiresCheckCurrent;

  bool get isBusy =>
      status == TeacherHomeworkLifecycleStatus.submitting ||
      status == TeacherHomeworkLifecycleStatus.reconciling;

  bool get canCheckCurrent =>
      status == TeacherHomeworkLifecycleStatus.outcomeReview &&
      action != null &&
      requiresCheckCurrent;

  bool get hasBlockingOutcome => canCheckCurrent;
  bool get blocksMutations => isBusy || hasBlockingOutcome;

  TeacherHomeworkLifecycleState withoutFeedback() {
    return TeacherHomeworkLifecycleState(
      status: status,
      action: action,
      notice: notice,
      conflictCode: conflictCode,
      requiresCheckCurrent: requiresCheckCurrent,
    );
  }
}
