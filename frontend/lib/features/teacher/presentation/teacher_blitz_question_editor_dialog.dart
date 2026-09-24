import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../application/teacher_blitz_question_builder_controller.dart';
import '../application/teacher_blitz_question_editor_controller.dart';
import '../application/teacher_blitz_question_editor_target.dart';
import '../application/teacher_blitz_route_target.dart';
import '../application/teacher_question_draft_commands.dart';
import '../application/teacher_question_editor_state.dart';
import '../application/teacher_session_key.dart';
import 'teacher_question_editor_shell.dart';

class TeacherBlitzQuestionEditorDialog extends StatelessWidget {
  const TeacherBlitzQuestionEditorDialog.add({
    required this.routeTarget,
    required this.routeOwnerGeneration,
    required this.editorGeneration,
    super.key,
  }) : mode = TeacherQuestionEditorMode.add,
       questionId = null;

  const TeacherBlitzQuestionEditorDialog.edit({
    required this.routeTarget,
    required this.routeOwnerGeneration,
    required String this.questionId,
    required this.editorGeneration,
    super.key,
  }) : mode = TeacherQuestionEditorMode.edit;

  final TeacherBlitzRouteTarget routeTarget;
  final int routeOwnerGeneration;
  final TeacherQuestionEditorMode mode;
  final String? questionId;
  final int editorGeneration;

  @override
  Widget build(BuildContext context) {
    return TeacherQuestionEditorShell(
      mode: mode,
      binding: _BlitzQuestionEditorBinding(
        TeacherBlitzQuestionEditorTarget(
          routeTarget: routeTarget,
          routeOwnerGeneration: routeOwnerGeneration,
          mode: mode,
          questionId: questionId,
          editorGeneration: editorGeneration,
        ),
      ),
    );
  }
}

class _BlitzQuestionEditorBinding implements TeacherQuestionEditorBinding {
  const _BlitzQuestionEditorBinding(this.target);

  final TeacherBlitzQuestionEditorTarget target;

  @override
  String get assessmentLabel => 'Blitz';

  @override
  ProviderListenable<TeacherQuestionEditorState> get state =>
      teacherBlitzQuestionEditorControllerProvider(target);

  @override
  TeacherQuestionDraftCommands commands(WidgetRef ref) =>
      ref.read(teacherBlitzQuestionEditorControllerProvider(target).notifier);

  @override
  Future<void> submit(WidgetRef ref) => ref
      .read(teacherBlitzQuestionEditorControllerProvider(target).notifier)
      .submit();

  @override
  Future<void> checkCurrent(WidgetRef ref) => ref
      .read(teacherBlitzQuestionEditorControllerProvider(target).notifier)
      .checkCurrentBlitz();

  @override
  bool isCurrentRouteOwner(WidgetRef ref, TeacherSessionKey owner) => ref
      .read(
        teacherBlitzQuestionBuilderControllerProvider(
          target.routeTarget,
        ).notifier,
      )
      .isCurrentRouteOwner(owner, ownerGeneration: target.routeOwnerGeneration);
}
