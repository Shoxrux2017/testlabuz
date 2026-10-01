import '../../../core/network/api_failure.dart';
import '../domain/teacher_official_score.dart';

enum TeacherOfficialScoreLoadStatus {
  initial,
  loading,
  data,
  refreshing,
  notFound,
  error,
}

class TeacherOfficialScoreState {
  const TeacherOfficialScoreState({
    this.status = TeacherOfficialScoreLoadStatus.initial,
    this.score,
    this.failure,
    this.isStale = false,
  });

  final TeacherOfficialScoreLoadStatus status;
  final TeacherOfficialScore? score;
  final ApiFailure? failure;

  /// True only when [score] is retained after a failed refresh.
  final bool isStale;

  bool get isLoading =>
      status == TeacherOfficialScoreLoadStatus.loading ||
      status == TeacherOfficialScoreLoadStatus.refreshing;
}
