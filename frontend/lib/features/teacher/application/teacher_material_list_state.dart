import '../../../core/network/api_failure.dart';
import '../domain/teacher_learning_material.dart';

enum TeacherMaterialListStatus { initial, loading, data, refreshing, error }

class TeacherMaterialListState {
  const TeacherMaterialListState({
    this.status = TeacherMaterialListStatus.initial,
    this.collection,
    this.failure,
    this.isStale = false,
  });

  final TeacherMaterialListStatus status;
  final TeacherLearningMaterialCollection? collection;
  final ApiFailure? failure;
  final bool isStale;

  bool get isLoading =>
      status == TeacherMaterialListStatus.loading ||
      status == TeacherMaterialListStatus.refreshing;
}
