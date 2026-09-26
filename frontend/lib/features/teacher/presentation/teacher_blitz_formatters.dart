import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_attempt_exception.dart';
import '../domain/teacher_blitz_monitoring.dart';
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

String teacherBlitzMonitoringStatusLabel(
  TeacherBlitzMonitoringStudentStatus status,
) {
  return switch (status) {
    TeacherBlitzMonitoringStudentStatus.notStarted => 'Not started',
    TeacherBlitzMonitoringStudentStatus.inProgress => 'In progress',
    TeacherBlitzMonitoringStudentStatus.finalized => 'Finalized',
    TeacherBlitzMonitoringStudentStatus.waitingForTeacherReview =>
      'Waiting for Teacher review',
  };
}

String teacherBlitzFinalizationReasonLabel(
  TeacherBlitzMonitoringFinalizationReason reason,
) {
  return switch (reason) {
    TeacherBlitzMonitoringFinalizationReason.studentSubmit =>
      'Submitted by Student',
    TeacherBlitzMonitoringFinalizationReason.timeout => 'Time expired',
    TeacherBlitzMonitoringFinalizationReason.taskClosed =>
      'Finalized when Blitz closed',
  };
}

String teacherBlitzAttemptExceptionReasonTypeLabel(
  TeacherBlitzAttemptExceptionReasonType type,
) {
  return switch (type) {
    TeacherBlitzAttemptExceptionReasonType.technical => 'Technical problem',
    TeacherBlitzAttemptExceptionReasonType.otherValid => 'Other valid reason',
  };
}

/// Attempt #2 exists only as the replacement of an exception grant.
String teacherBlitzAttemptNumberLabel(int? attemptNumber) {
  return switch (attemptNumber) {
    null => '—',
    1 => 'Attempt 1',
    _ => 'Additional attempt',
  };
}

/// Formats a server remaining-time snapshot; never computed from device time.
String formatTeacherBlitzRemaining(int? remainingSeconds) {
  if (remainingSeconds == null) {
    return '—';
  }
  final hours = remainingSeconds ~/ Duration.secondsPerHour;
  final minutes =
      remainingSeconds % Duration.secondsPerHour ~/ Duration.secondsPerMinute;
  final seconds = remainingSeconds % Duration.secondsPerMinute;
  String two(int value) => value.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds)}'
      : '${two(minutes)}:${two(seconds)}';
}
