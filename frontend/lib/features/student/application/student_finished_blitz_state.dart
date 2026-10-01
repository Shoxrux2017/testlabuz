import '../../../core/network/api_failure.dart';
import '../domain/student_finished_blitz.dart';

enum StudentFinishedBlitzLoadStatus {
  initial,
  loading,
  data,
  refreshing,
  error,
}

class StudentFinishedBlitzState {
  const StudentFinishedBlitzState({
    this.status = StudentFinishedBlitzLoadStatus.initial,
    this.page,
    this.failure,
    this.isStale = false,
  });

  final StudentFinishedBlitzLoadStatus status;

  /// `null` until a page has loaded once in this session.
  final StudentFinishedBlitzPage? page;
  final ApiFailure? failure;

  /// A retained page survives a failed request but may no longer be current.
  final bool isStale;

  bool get isRequestInFlight =>
      status == StudentFinishedBlitzLoadStatus.loading ||
      status == StudentFinishedBlitzLoadStatus.refreshing;

  bool get canGoPrevious =>
      !isRequestInFlight && page != null && page!.page > 1;

  bool get canGoNext =>
      !isRequestInFlight && page != null && page!.page < page!.lastPage;
}
