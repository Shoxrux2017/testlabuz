import '../domain/teacher_homework.dart';
import '../domain/teacher_question.dart';
import 'teacher_topic_formatters.dart';

String teacherHomeworkStatusLabel(TeacherHomeworkStatus status) {
  return switch (status) {
    TeacherHomeworkStatus.draft => 'Draft',
    TeacherHomeworkStatus.active => 'Active',
    TeacherHomeworkStatus.closed => 'Closed',
    TeacherHomeworkStatus.archived => 'Archived',
  };
}

String teacherHomeworkAssignmentLabel(TeacherHomeworkAssignmentMode mode) {
  return switch (mode) {
    TeacherHomeworkAssignmentMode.group => 'Whole group',
    TeacherHomeworkAssignmentMode.selectedStudents => 'Selected students',
  };
}

String teacherQuestionTypeLabel(TeacherQuestionType type) {
  return switch (type) {
    TeacherQuestionType.singleChoice => 'Single choice',
    TeacherQuestionType.multipleChoice => 'Multiple choice',
    TeacherQuestionType.trueFalse => 'True/False',
    TeacherQuestionType.shortWritten => 'Short written',
    TeacherQuestionType.openWritten => 'Open written',
    TeacherQuestionType.fileBased => 'File based',
    TeacherQuestionType.matching => 'Matching',
    TeacherQuestionType.ordering => 'Ordering',
    TeacherQuestionType.fillInBlank => 'Fill in the blank',
  };
}

String teacherQuestionCheckingModeLabel(TeacherQuestionCheckingMode mode) {
  return switch (mode) {
    TeacherQuestionCheckingMode.automatic => 'Automatic',
    TeacherQuestionCheckingMode.manual => 'Manual',
  };
}

String formatTeacherHomeworkPoints(num points) {
  final value = points.toDouble();
  return value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();
}

String formatTeacherHomeworkDeadline(
  DateTime? deadlineAt,
  String institutionTimezone,
) {
  if (deadlineAt == null) {
    return 'No deadline';
  }

  return formatInstitutionInstant(deadlineAt, institutionTimezone) ??
      'Institution timezone unavailable';
}

String teacherHomeworkOfficialScorePolicyLabel(String policy) {
  return switch (policy) {
    TeacherHomeworkAttemptPolicy.requiredOfficialScorePolicy =>
      'Highest valid completed attempt',
    _ => 'Unavailable',
  };
}
