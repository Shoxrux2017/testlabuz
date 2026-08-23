import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class InstitutionWallClock {
  const InstitutionWallClock({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    this.second = 0,
  });

  factory InstitutionWallClock.fromDateTime(DateTime value) {
    return InstitutionWallClock(
      year: value.year,
      month: value.month,
      day: value.day,
      hour: value.hour,
      minute: value.minute,
      second: value.second,
    );
  }

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final int second;

  DateTime get date => DateTime(year, month, day);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InstitutionWallClock &&
            other.year == year &&
            other.month == month &&
            other.day == day &&
            other.hour == hour &&
            other.minute == minute &&
            other.second == second;
  }

  @override
  int get hashCode => Object.hash(year, month, day, hour, minute, second);
}

class InstitutionTimezoneException implements Exception {
  const InstitutionTimezoneException(this.reason);

  final InstitutionTimezoneFailureReason reason;
}

enum InstitutionTimezoneFailureReason { unknownTimezone, nonexistentLocalTime }

abstract final class InstitutionTimezone {
  static var _initialized = false;

  static void initialize() {
    if (_initialized) {
      return;
    }
    timezone_data.initializeTimeZones();
    _initialized = true;
  }

  static timezone.Location? tryResolve(String ianaIdentifier) {
    initialize();
    final identifier = ianaIdentifier.trim();
    if (identifier.isEmpty) {
      return null;
    }
    try {
      return timezone.getLocation(identifier);
    } on timezone.LocationNotFoundException {
      return null;
    }
  }

  static InstitutionWallClock? instantToWallClock(
    DateTime? instant,
    String ianaIdentifier,
  ) {
    if (instant == null) {
      return null;
    }
    final location = tryResolve(ianaIdentifier);
    if (location == null) {
      throw const InstitutionTimezoneException(
        InstitutionTimezoneFailureReason.unknownTimezone,
      );
    }
    final local = timezone.TZDateTime.from(instant.toUtc(), location);

    return InstitutionWallClock.fromDateTime(local);
  }

  static DateTime? wallClockToInstant(
    InstitutionWallClock? wallClock,
    String ianaIdentifier,
  ) {
    if (wallClock == null) {
      return null;
    }

    return _resolveWallClock(wallClock, ianaIdentifier).toUtc();
  }

  static String? serializeWallClock(
    InstitutionWallClock? wallClock,
    String ianaIdentifier,
  ) {
    if (wallClock == null) {
      return null;
    }
    final local = _resolveWallClock(wallClock, ianaIdentifier);
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absoluteMinutes = offset.inMinutes.abs();
    final offsetHours = absoluteMinutes ~/ Duration.minutesPerHour;
    final offsetMinutes = absoluteMinutes % Duration.minutesPerHour;

    return '${_four(local.year)}-${_two(local.month)}-${_two(local.day)}'
        'T${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}'
        '$sign${_two(offsetHours)}:${_two(offsetMinutes)}';
  }

  static timezone.TZDateTime _resolveWallClock(
    InstitutionWallClock wallClock,
    String ianaIdentifier,
  ) {
    final location = tryResolve(ianaIdentifier);
    if (location == null) {
      throw const InstitutionTimezoneException(
        InstitutionTimezoneFailureReason.unknownTimezone,
      );
    }
    final local = timezone.TZDateTime(
      location,
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
      wallClock.second,
    );
    if (local.year != wallClock.year ||
        local.month != wallClock.month ||
        local.day != wallClock.day ||
        local.hour != wallClock.hour ||
        local.minute != wallClock.minute ||
        local.second != wallClock.second) {
      throw const InstitutionTimezoneException(
        InstitutionTimezoneFailureReason.nonexistentLocalTime,
      );
    }

    return local;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
  static String _four(int value) => value.toString().padLeft(4, '0');
}
