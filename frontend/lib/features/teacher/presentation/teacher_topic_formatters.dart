import '../../../core/time/institution_timezone.dart';
import '../domain/teacher_group.dart';
import '../domain/teacher_topic.dart';

String teacherTopicStatusLabel(TeacherTopicStatus status) {
  return switch (status) {
    TeacherTopicStatus.draft => 'Draft',
    TeacherTopicStatus.active => 'Active',
    TeacherTopicStatus.closed => 'Closed',
    TeacherTopicStatus.archived => 'Archived',
  };
}

String teacherGroupStatusLabel(TeacherGroupStatus status) {
  return switch (status) {
    TeacherGroupStatus.active => 'Active',
    TeacherGroupStatus.archived => 'Archived',
  };
}

String formatInstitutionWallClock(InstitutionWallClock value) {
  return '${_four(value.year)}-${_two(value.month)}-${_two(value.day)} '
      '${_two(value.hour)}:${_two(value.minute)}';
}

String? formatInstitutionInstant(DateTime? instant, String timezone) {
  if (instant == null) {
    return null;
  }
  try {
    final wallClock = InstitutionTimezone.instantToWallClock(instant, timezone);
    return wallClock == null ? null : formatInstitutionWallClock(wallClock);
  } on InstitutionTimezoneException {
    return null;
  }
}

String formatUtcInstant(DateTime value) {
  final utc = value.toUtc();
  return '${_four(utc.year)}-${_two(utc.month)}-${_two(utc.day)} '
      '${_two(utc.hour)}:${_two(utc.minute)} UTC';
}

String _two(int value) => value.toString().padLeft(2, '0');
String _four(int value) => value.toString().padLeft(4, '0');
