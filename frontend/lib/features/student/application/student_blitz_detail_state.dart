import '../../../core/network/api_failure.dart';
import '../domain/student_blitz.dart';

enum StudentBlitzDetailStatus {
  initial,
  loading,
  data,
  refreshing,
  notFound,
  notActive,
  timeExpired,
  error,
}

class StudentBlitzDetailState {
  const StudentBlitzDetailState({
    this.status = StudentBlitzDetailStatus.initial,
    this.blitz,
    this.failure,
  });

  final StudentBlitzDetailStatus status;

  /// Present for `data`, and retained only while `refreshing`. It authorizes
  /// a new Start only when [status] is `data`.
  final StudentBlitzDetail? blitz;
  final ApiFailure? failure;

  bool get isRequestInFlight =>
      status == StudentBlitzDetailStatus.loading ||
      status == StudentBlitzDetailStatus.refreshing;

  /// The confirmed detail that may authorize a new Start/Resume.
  StudentBlitzDetail? get confirmedBlitz =>
      status == StudentBlitzDetailStatus.data ? blitz : null;
}
