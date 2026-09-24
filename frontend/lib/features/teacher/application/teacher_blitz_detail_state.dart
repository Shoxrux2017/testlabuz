import '../../../core/network/api_failure.dart';
import '../domain/teacher_blitz.dart';

enum TeacherBlitzDetailStatus {
  initial,
  loading,
  data,
  refreshing,
  notFound,
  error,
}

class TeacherBlitzDetailState {
  const TeacherBlitzDetailState({
    this.status = TeacherBlitzDetailStatus.initial,
    this.blitz,
    this.failure,
    this.isStale = false,
  });

  final TeacherBlitzDetailStatus status;
  final TeacherBlitz? blitz;
  final ApiFailure? failure;

  /// True only when [blitz] is retained after a failed refresh.
  final bool isStale;

  bool get isLoading =>
      status == TeacherBlitzDetailStatus.loading ||
      status == TeacherBlitzDetailStatus.refreshing;
}
