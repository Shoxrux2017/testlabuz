enum TeacherBlitzAttemptExceptionStatus {
  idle,
  submitting,
  uncertain,
  checking,
  confirmed,
  failure,
}

class TeacherBlitzAttemptExceptionState {
  const TeacherBlitzAttemptExceptionState({
    this.status = TeacherBlitzAttemptExceptionStatus.idle,
    this.studentId,
    this.message,
    this.canRetry = false,
    this.canCheckMonitoring = false,
  });

  final TeacherBlitzAttemptExceptionStatus status;

  /// The Student the current operation or outcome belongs to.
  final String? studentId;
  final String? message;

  /// Whether the unresolved grant may be resent with its original key.
  final bool canRetry;
  final bool canCheckMonitoring;

  bool get isBusy =>
      status == TeacherBlitzAttemptExceptionStatus.submitting ||
      status == TeacherBlitzAttemptExceptionStatus.checking;

  /// While a grant is sent, unresolved or reconciled, it owns the monitoring
  /// route: live polling and new grants pause.
  bool get ownsMonitoring =>
      isBusy || status == TeacherBlitzAttemptExceptionStatus.uncertain;
}
