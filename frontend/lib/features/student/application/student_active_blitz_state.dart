import '../../../core/network/api_failure.dart';
import '../domain/student_blitz.dart';

enum StudentActiveBlitzStatus { initial, loading, data, refreshing, error }

class StudentActiveBlitzState {
  const StudentActiveBlitzState({
    this.status = StudentActiveBlitzStatus.initial,
    this.items,
    this.failure,
    this.isStale = false,
  });

  final StudentActiveBlitzStatus status;

  /// `null` until the server list has loaded once in this session.
  final List<StudentActiveBlitzSummary>? items;
  final ApiFailure? failure;

  /// Retained items survive a failed refresh but may no longer be current.
  final bool isStale;

  bool get isRequestInFlight =>
      status == StudentActiveBlitzStatus.loading ||
      status == StudentActiveBlitzStatus.refreshing;
}
