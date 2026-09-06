import '../../../core/network/api_failure.dart';
import '../domain/teacher_homework.dart';

enum TeacherHomeworkDetailStatus {
  initial,
  loading,
  data,
  refreshing,
  notFound,
  error,
}

class TeacherHomeworkDetailState {
  const TeacherHomeworkDetailState({
    this.status = TeacherHomeworkDetailStatus.initial,
    this.homework,
    this.failure,
    this.isStale = false,
  });

  final TeacherHomeworkDetailStatus status;
  final TeacherHomework? homework;
  final ApiFailure? failure;

  /// True only when [homework] is retained after a failed refresh.
  final bool isStale;

  bool get isLoading =>
      status == TeacherHomeworkDetailStatus.loading ||
      status == TeacherHomeworkDetailStatus.refreshing;
}
