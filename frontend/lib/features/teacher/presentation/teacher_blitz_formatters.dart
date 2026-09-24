import '../domain/teacher_blitz.dart';
import 'teacher_topic_formatters.dart';

String teacherBlitzStatusLabel(TeacherBlitzStatus status) {
  return switch (status) {
    TeacherBlitzStatus.draft => 'Draft',
    TeacherBlitzStatus.scheduled => 'Scheduled',
    TeacherBlitzStatus.active => 'Active',
    TeacherBlitzStatus.closed => 'Closed',
    TeacherBlitzStatus.archived => 'Archived',
  };
}

String teacherBlitzAssignmentLabel(TeacherBlitzAssignmentMode mode) {
  return switch (mode) {
    TeacherBlitzAssignmentMode.group => 'Whole group',
    TeacherBlitzAssignmentMode.selectedStudents => 'Selected students',
  };
}

String teacherBlitzTimerModeLabel(TeacherBlitzTimerStartMode? mode) {
  return switch (mode) {
    null => 'Not snapshotted until activation',
    TeacherBlitzTimerStartMode.synchronized => 'Synchronized',
    TeacherBlitzTimerStartMode.individual => 'Individual',
  };
}

String formatTeacherBlitzDuration(int durationSeconds) {
  if (durationSeconds < 1) {
    throw ArgumentError.value(
      durationSeconds,
      'durationSeconds',
      'Blitz duration must be positive.',
    );
  }
  final hours = durationSeconds ~/ Duration.secondsPerHour;
  final minutes =
      durationSeconds % Duration.secondsPerHour ~/ Duration.secondsPerMinute;
  final seconds = durationSeconds % Duration.secondsPerMinute;

  return [
    if (hours > 0) '$hours hr',
    if (minutes > 0) '$minutes min',
    if (seconds > 0) '$seconds sec',
  ].join(' ');
}

String formatTeacherBlitzScheduledAt(
  DateTime? scheduledAt,
  String institutionTimezone,
) {
  if (scheduledAt == null) {
    return 'Not scheduled';
  }

  return formatInstitutionInstant(scheduledAt, institutionTimezone) ??
      'Institution timezone unavailable';
}
