import '../../../core/network/api_failure.dart';

enum StudentHomeworkSubmitStatus {
  idle,
  submitting,
  uncertain,
  checking,
  failure,
  completed,
  reconciledTerminal,
}

enum StudentHomeworkSubmitTerminalReconciliationReason {
  studentSubmitAlreadyTerminal,
  homeworkDeadlineAutoFinalized,
  taskClosedAutoFinalized,
}

class StudentHomeworkSubmitState {
  const StudentHomeworkSubmitState({
    this.status = StudentHomeworkSubmitStatus.idle,
    this.failure,
    this.notice,
    this.terminalReconciliationReason,
  });

  final StudentHomeworkSubmitStatus status;
  final ApiFailure? failure;
  final String? notice;
  final StudentHomeworkSubmitTerminalReconciliationReason?
  terminalReconciliationReason;
}
