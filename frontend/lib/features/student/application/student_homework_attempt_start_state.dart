import '../../../core/network/api_failure.dart';
import '../domain/student_homework_attempt.dart';

enum StudentHomeworkAttemptStartStatus {
  idle,
  submitting,
  uncertain,
  failure,
  completed,
}

class StudentHomeworkAttemptStartState {
  const StudentHomeworkAttemptStartState({
    this.status = StudentHomeworkAttemptStartStatus.idle,
    this.failure,
    this.completedAttemptId,
    this.completedResultKind,
  });

  final StudentHomeworkAttemptStartStatus status;
  final ApiFailure? failure;
  final String? completedAttemptId;
  final StudentHomeworkAttemptStartResultKind? completedResultKind;
}
