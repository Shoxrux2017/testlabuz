import '../../../core/network/api_failure.dart';
import '../domain/student_homework_attempt.dart';

enum StudentHomeworkAttemptLoadStatus {
  initial,
  loading,
  data,
  refreshing,
  notFound,
  error,
}

class StudentHomeworkAttemptState {
  const StudentHomeworkAttemptState({
    this.status = StudentHomeworkAttemptLoadStatus.initial,
    this.attempt,
    this.failure,
  });

  final StudentHomeworkAttemptLoadStatus status;
  final StudentHomeworkAttempt? attempt;
  final ApiFailure? failure;

  bool get isRequestInFlight =>
      status == StudentHomeworkAttemptLoadStatus.loading ||
      status == StudentHomeworkAttemptLoadStatus.refreshing;
}
