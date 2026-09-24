import '../domain/teacher_blitz_form.dart';

/// Safe copy for a server-rejected Blitz form field.
String teacherBlitzServerValidationMessage(TeacherBlitzFormField field) {
  return switch (field) {
    TeacherBlitzFormField.title => 'Review the Blitz title.',
    TeacherBlitzFormField.description => 'Review the description.',
    TeacherBlitzFormField.studentInstructions =>
      'Review the student instructions.',
    TeacherBlitzFormField.assignmentMode => 'Review the assignment mode.',
    TeacherBlitzFormField.studentIds =>
      'Review the selected Students. One or more selections may no longer be eligible.',
    TeacherBlitzFormField.durationSeconds => 'Review the Blitz duration.',
  };
}
