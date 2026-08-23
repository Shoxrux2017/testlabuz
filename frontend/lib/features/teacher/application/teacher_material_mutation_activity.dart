import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TeacherMaterialMutationActivityKind {
  upload,
  replace,
  updateTitle,
  remove,
}

class TeacherMaterialMutationActivityState {
  const TeacherMaterialMutationActivityState({
    this.kind,
    this.materialId,
    this.fileId,
    this.generation = 0,
  });

  final TeacherMaterialMutationActivityKind? kind;
  final String? materialId;
  final String? fileId;
  final int generation;

  bool get isActive => kind != null;

  bool blocksTransfer(String targetMaterialId) {
    return materialId?.toLowerCase() == targetMaterialId.toLowerCase() &&
        (kind == TeacherMaterialMutationActivityKind.replace ||
            kind == TeacherMaterialMutationActivityKind.remove);
  }
}

final teacherMaterialMutationActivityProvider = NotifierProvider.autoDispose
    .family<
      TeacherMaterialMutationActivity,
      TeacherMaterialMutationActivityState,
      String
    >(TeacherMaterialMutationActivity.new);

class TeacherMaterialMutationActivity
    extends Notifier<TeacherMaterialMutationActivityState> {
  TeacherMaterialMutationActivity(this.topicId);

  final String topicId;

  @override
  TeacherMaterialMutationActivityState build() {
    return const TeacherMaterialMutationActivityState();
  }

  int activate({
    required TeacherMaterialMutationActivityKind kind,
    String? materialId,
    String? fileId,
  }) {
    if (state.isActive) {
      return -1;
    }
    final generation = state.generation + 1;
    state = TeacherMaterialMutationActivityState(
      kind: kind,
      materialId: materialId,
      fileId: fileId,
      generation: generation,
    );
    return generation;
  }

  void clear(int generation) {
    if (state.generation != generation) {
      return;
    }
    state = TeacherMaterialMutationActivityState(generation: generation);
  }
}
