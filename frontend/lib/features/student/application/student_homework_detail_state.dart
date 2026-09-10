import '../../../core/network/api_failure.dart';
import '../domain/student_homework.dart';

enum StudentHomeworkDetailStatus {
  initial,
  loading,
  data,
  refreshing,
  notFound,
  error,
}

class StudentHomeworkDetailState {
  const StudentHomeworkDetailState({
    this.status = StudentHomeworkDetailStatus.initial,
    this.homework,
    this.failure,
  });

  final StudentHomeworkDetailStatus status;
  final StudentHomeworkDetail? homework;
  final ApiFailure? failure;

  bool get isRequestInFlight =>
      status == StudentHomeworkDetailStatus.loading ||
      status == StudentHomeworkDetailStatus.refreshing;
}
