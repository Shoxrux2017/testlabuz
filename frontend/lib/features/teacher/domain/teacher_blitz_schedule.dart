import '../../../core/time/institution_timezone.dart';
import 'teacher_blitz.dart';

/// One Schedule/Reschedule request for a planned Institution wall clock.
///
/// Only wall-clock existence is validated here; whether the instant is far
/// enough in the future is decided by the server clock, never the device.
class TeacherBlitzScheduleRequest {
  TeacherBlitzScheduleRequest._({
    required this.scheduledAt,
    required this.scheduledInstant,
  });

  /// Throws [InstitutionTimezoneException] for an unknown timezone or a
  /// wall clock that does not exist in it.
  factory TeacherBlitzScheduleRequest.fromWallClock(
    InstitutionWallClock wallClock,
    String institutionTimezone,
  ) {
    final instant = InstitutionTimezone.wallClockToInstant(
      wallClock,
      institutionTimezone,
    )!;
    final serialized = InstitutionTimezone.serializeWallClock(
      wallClock,
      institutionTimezone,
    )!;
    return TeacherBlitzScheduleRequest._(
      scheduledAt: serialized,
      scheduledInstant: instant.toUtc(),
    );
  }

  /// `YYYY-MM-DDTHH:mm:ss±HH:mm` in the Institution offset.
  final String scheduledAt;
  final DateTime scheduledInstant;

  /// A Scheduled Blitz already planned for this exact instant needs no POST;
  /// a Draft still does, because the POST performs Draft -> Scheduled.
  bool isNoOpFor(TeacherBlitz blitz) {
    final current = blitz.scheduledAt;
    return blitz.status == TeacherBlitzStatus.scheduled &&
        current != null &&
        current.isAtSameMomentAs(scheduledInstant);
  }

  bool isConfirmedBy(TeacherBlitz blitz) => isNoOpFor(blitz);

  Map<String, Object?> toJson() => {'scheduled_at': scheduledAt};
}
