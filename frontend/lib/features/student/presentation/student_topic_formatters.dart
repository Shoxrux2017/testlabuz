import '../../../core/time/institution_timezone.dart';
import '../domain/student_topic.dart';

String studentTopicStatusLabel(StudentTopicStatus status) {
  return switch (status) {
    StudentTopicStatus.active => 'Active',
    StudentTopicStatus.closed => 'Closed',
    StudentTopicStatus.archived => 'Archived',
  };
}

String studentGroupStatusLabel(StudentGroupStatus status) {
  return switch (status) {
    StudentGroupStatus.active => 'Active',
    StudentGroupStatus.archived => 'Archived',
  };
}

String? formatStudentInstitutionInstant(DateTime? instant, String timezone) {
  if (instant == null) {
    return null;
  }
  try {
    final wallClock = InstitutionTimezone.instantToWallClock(instant, timezone);
    if (wallClock == null) {
      return null;
    }
    return '${_four(wallClock.year)}-${_two(wallClock.month)}-'
        '${_two(wallClock.day)} ${_two(wallClock.hour)}:'
        '${_two(wallClock.minute)}';
  } on InstitutionTimezoneException {
    return null;
  }
}

String formatStudentMaterialBytes(int bytes) {
  const mebibyte = 1024 * 1024;
  if (bytes >= mebibyte) {
    final value = bytes / mebibyte;
    return '${value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} MiB';
  }
  const kibibyte = 1024;
  if (bytes >= kibibyte) {
    return '${(bytes / kibibyte).toStringAsFixed(1)} KiB';
  }
  return '$bytes bytes';
}

String _two(int value) => value.toString().padLeft(2, '0');
String _four(int value) => value.toString().padLeft(4, '0');
