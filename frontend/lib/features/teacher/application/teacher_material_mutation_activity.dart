import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'teacher_session_key.dart';

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
    this.owner,
    this.generation = 0,
  });

  final TeacherMaterialMutationActivityKind? kind;
  final String? materialId;
  final String? fileId;
  final TeacherSessionKey? owner;
  final int generation;

  bool get isActive => kind != null;

  bool isActiveFor(TeacherSessionKey? candidate) {
    return candidate != null && isActive && owner == candidate;
  }

  bool blocksTransfer(String targetMaterialId, TeacherSessionKey? candidate) {
    return isActiveFor(candidate) &&
        materialId?.toLowerCase() == targetMaterialId.toLowerCase() &&
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
    required TeacherSessionKey owner,
    required TeacherMaterialMutationActivityKind kind,
    String? materialId,
    String? fileId,
  }) {
    if (state.isActiveFor(owner)) {
      return -1;
    }
    final generation = state.generation + 1;
    state = TeacherMaterialMutationActivityState(
      kind: kind,
      materialId: materialId,
      fileId: fileId,
      owner: owner,
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
