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

/// Identifies one authoritative parent publication, without encoding its data.
class StudentHomeworkAttemptPublicationToken {
  StudentHomeworkAttemptPublicationToken();
}

class StudentHomeworkAttemptState {
  const StudentHomeworkAttemptState({
    this.status = StudentHomeworkAttemptLoadStatus.initial,
    this.attempt,
    this.failure,
    this.publicationToken,
  });

  final StudentHomeworkAttemptLoadStatus status;
  final StudentHomeworkAttempt? attempt;
  final ApiFailure? failure;
  final StudentHomeworkAttemptPublicationToken? publicationToken;

  bool get isRequestInFlight =>
      status == StudentHomeworkAttemptLoadStatus.loading ||
      status == StudentHomeworkAttemptLoadStatus.refreshing;
}
