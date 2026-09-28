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
    this.readToken,
  });

  final StudentHomeworkAttemptLoadStatus status;
  final StudentHomeworkAttempt? attempt;
  final ApiFailure? failure;

  /// Changes with every publication, including answer patches.
  final StudentHomeworkAttemptPublicationToken? publicationToken;

  /// Changes only with a full Attempt read or terminal adoption, so a write
  /// that started from this read can still patch its answer afterwards.
  final StudentHomeworkAttemptPublicationToken? readToken;

  bool get isRequestInFlight =>
      status == StudentHomeworkAttemptLoadStatus.loading ||
      status == StudentHomeworkAttemptLoadStatus.refreshing;
}
