import '../../../core/network/api_failure.dart';
import '../domain/student_homework_list.dart';
import '../domain/student_homework_list_query.dart';

enum StudentHomeworkListStatus {
  initial,
  loading,
  data,
  empty,
  refreshing,
  error,
}

class StudentHomeworkListState {
  const StudentHomeworkListState({
    required this.query,
    this.status = StudentHomeworkListStatus.initial,
    this.page,
    this.failure,
    this.isStale = false,
  });

  factory StudentHomeworkListState.fromPage({
    required StudentHomeworkListQuery query,
    required StudentHomeworkList page,
  }) {
    return StudentHomeworkListState(
      query: query,
      status: page.items.isEmpty
          ? StudentHomeworkListStatus.empty
          : StudentHomeworkListStatus.data,
      page: page,
    );
  }

  final StudentHomeworkListStatus status;
  final StudentHomeworkListQuery query;
  final StudentHomeworkList? page;
  final ApiFailure? failure;
  final bool isStale;

  bool get isRequestInFlight =>
      status == StudentHomeworkListStatus.loading ||
      status == StudentHomeworkListStatus.refreshing;

  bool get canGoPrevious =>
      !isRequestInFlight && !isStale && (page?.page ?? 1) > 1;

  bool get canGoNext =>
      !isRequestInFlight &&
      !isStale &&
      page != null &&
      page!.page < page!.lastPage;
}
