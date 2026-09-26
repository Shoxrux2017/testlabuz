import '../../../core/network/api_failure.dart';
import '../domain/student_homework_attempt.dart';
import 'student_attempt_publication_token.dart';

enum StudentHomeworkAttemptLoadStatus {
  initial,
  loading,
  data,
  refreshing,
  notFound,
  error,
}

/// Shared with Blitz so the type-neutral file answer state can be reused.
typedef StudentHomeworkAttemptPublicationToken = StudentAttemptPublicationToken;

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
