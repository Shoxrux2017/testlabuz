import '../domain/teacher_question_authoring.dart';
import '../domain/teacher_question_mutation.dart';

/// Maps a server `422` key such as `configuration.options.0` to its field.
TeacherQuestionDraftField? teacherQuestionDraftFieldForServerKey(String key) {
  final root = key.split('.').first;
  return switch (TeacherQuestionMutationField.fromRequestKey(root)) {
    TeacherQuestionMutationField.type => TeacherQuestionDraftField.type,
    TeacherQuestionMutationField.prompt => TeacherQuestionDraftField.prompt,
    TeacherQuestionMutationField.instructions =>
      TeacherQuestionDraftField.instructions,
    TeacherQuestionMutationField.points => TeacherQuestionDraftField.points,
    TeacherQuestionMutationField.checkingMode =>
      TeacherQuestionDraftField.checkingMode,
    TeacherQuestionMutationField.configuration =>
      TeacherQuestionDraftField.configuration,
    null => null,
  };
}

/// Safe copy for a server-rejected Question field.
String teacherQuestionServerValidationMessage(TeacherQuestionDraftField field) {
  return switch (field) {
    TeacherQuestionDraftField.type => 'Review the Question type.',
    TeacherQuestionDraftField.prompt => 'Review the Question prompt.',
    TeacherQuestionDraftField.instructions =>
      'Review the Question instructions.',
    TeacherQuestionDraftField.points => 'Review the Question points.',
    TeacherQuestionDraftField.checkingMode => 'Review the checking behavior.',
    TeacherQuestionDraftField.configuration =>
      'Review the Question configuration.',
  };
}
