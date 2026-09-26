import '../../../core/network/api_failure.dart';

enum StudentBlitzSubmitStatus {
  idle,
  submitting,
  uncertain,
  checking,
  completed,
  reconciledTerminal,
  failure,
}

class StudentBlitzSubmitState {
  const StudentBlitzSubmitState({
    this.status = StudentBlitzSubmitStatus.idle,
    this.failure,
    this.notice,
  });

  final StudentBlitzSubmitStatus status;
  final ApiFailure? failure;
  final String? notice;
}
