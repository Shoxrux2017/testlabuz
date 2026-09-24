import 'teacher_blitz_route_target.dart';
import 'teacher_question_editor_state.dart';

class TeacherBlitzQuestionEditorTarget {
  const TeacherBlitzQuestionEditorTarget({
    required this.routeTarget,
    required this.routeOwnerGeneration,
    required this.mode,
    required this.editorGeneration,
    this.questionId,
  }) : assert(
         (mode == TeacherQuestionEditorMode.add && questionId == null) ||
             (mode == TeacherQuestionEditorMode.edit && questionId != null),
       );

  final TeacherBlitzRouteTarget routeTarget;
  final int routeOwnerGeneration;
  final TeacherQuestionEditorMode mode;
  final String? questionId;
  final int editorGeneration;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TeacherBlitzQuestionEditorTarget &&
            other.routeTarget == routeTarget &&
            other.routeOwnerGeneration == routeOwnerGeneration &&
            other.mode == mode &&
            other.questionId?.toLowerCase() == questionId?.toLowerCase() &&
            other.editorGeneration == editorGeneration;
  }

  @override
  int get hashCode => Object.hash(
    routeTarget,
    routeOwnerGeneration,
    mode,
    questionId?.toLowerCase(),
    editorGeneration,
  );
}
