import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/time/institution_timezone.dart';

void main() {
  group('InstitutionTimezone', () {
    test('serializes Asia/Tashkent wall clock with seconds and +05:00', () {
      const selected = InstitutionWallClock(
        year: 2026,
        month: 8,
        day: 25,
        hour: 9,
        minute: 0,
      );

      expect(
        InstitutionTimezone.serializeWallClock(selected, 'Asia/Tashkent'),
        '2026-08-25T09:00:00+05:00',
      );
      expect(
        InstitutionTimezone.wallClockToInstant(selected, 'Asia/Tashkent'),
        DateTime.utc(2026, 8, 25, 4),
      );
    });

    test('converts a UTC resource to Institution-local wall clock', () {
      expect(
        InstitutionTimezone.instantToWallClock(
          DateTime.utc(2026, 8, 25, 4),
          'Asia/Tashkent',
        ),
        const InstitutionWallClock(
          year: 2026,
          month: 8,
          day: 25,
          hour: 9,
          minute: 0,
        ),
      );
    });

    test('uses New York summer and winter IANA offsets', () {
      expect(
        InstitutionTimezone.serializeWallClock(
          const InstitutionWallClock(
            year: 2026,
            month: 7,
            day: 15,
            hour: 9,
            minute: 30,
          ),
          'America/New_York',
        ),
        '2026-07-15T09:30:00-04:00',
      );
      expect(
        InstitutionTimezone.serializeWallClock(
          const InstitutionWallClock(
            year: 2026,
            month: 1,
            day: 15,
            hour: 9,
            minute: 30,
          ),
          'America/New_York',
        ),
        '2026-01-15T09:30:00-05:00',
      );
    });

    test('rejects nonexistent DST time instead of shifting it', () {
      expect(
        () => InstitutionTimezone.serializeWallClock(
          const InstitutionWallClock(
            year: 2026,
            month: 3,
            day: 8,
            hour: 2,
            minute: 30,
          ),
          'America/New_York',
        ),
        throwsA(
          isA<InstitutionTimezoneException>().having(
            (error) => error.reason,
            'reason',
            InstitutionTimezoneFailureReason.nonexistentLocalTime,
          ),
        ),
      );
    });

    test('keeps null null and never falls back for an unknown timezone', () {
      expect(
        InstitutionTimezone.serializeWallClock(null, 'Asia/Tashkent'),
        isNull,
      );
      expect(
        InstitutionTimezone.instantToWallClock(null, 'Asia/Tashkent'),
        isNull,
      );
      expect(InstitutionTimezone.tryResolve('Unknown/Device'), isNull);
      expect(
        () => InstitutionTimezone.serializeWallClock(
          const InstitutionWallClock(
            year: 2026,
            month: 8,
            day: 25,
            hour: 9,
            minute: 0,
          ),
          'Unknown/Device',
        ),
        throwsA(
          isA<InstitutionTimezoneException>().having(
            (error) => error.reason,
            'reason',
            InstitutionTimezoneFailureReason.unknownTimezone,
          ),
        ),
      );
    });
  });
}
