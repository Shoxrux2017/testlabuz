import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/core/time/institution_timezone.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz_schedule.dart';

import 'teacher_test_support.dart';

void main() {
  setUpAll(InstitutionTimezone.initialize);

  test('serializes the Institution wall clock with an explicit offset', () {
    final request = TeacherBlitzScheduleRequest.fromWallClock(
      const InstitutionWallClock(
        year: 2026,
        month: 9,
        day: 30,
        hour: 9,
        minute: 0,
      ),
      'Asia/Tashkent',
    );

    expect(request.scheduledAt, '2026-09-30T09:00:00+05:00');
    expect(request.scheduledInstant, DateTime.utc(2026, 9, 30, 4));
    expect(request.toJson(), {'scheduled_at': '2026-09-30T09:00:00+05:00'});
  });

  test('a UTC Institution still sends a numeric offset, never Z', () {
    final request = TeacherBlitzScheduleRequest.fromWallClock(
      const InstitutionWallClock(
        year: 2026,
        month: 1,
        day: 5,
        hour: 7,
        minute: 30,
      ),
      'UTC',
    );

    expect(request.scheduledAt, '2026-01-05T07:30:00+00:00');
  });

  test('a nonexistent or unresolvable wall clock cannot be scheduled', () {
    expect(
      () => TeacherBlitzScheduleRequest.fromWallClock(
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
    expect(
      () => TeacherBlitzScheduleRequest.fromWallClock(
        const InstitutionWallClock(
          year: 2026,
          month: 9,
          day: 30,
          hour: 9,
          minute: 0,
        ),
        'Mars/Olympus',
      ),
      throwsA(isA<InstitutionTimezoneException>()),
    );
  });

  test('the device clock never rejects a past or present time', () {
    final request = TeacherBlitzScheduleRequest.fromWallClock(
      const InstitutionWallClock(
        year: 2001,
        month: 1,
        day: 1,
        hour: 0,
        minute: 0,
      ),
      'Asia/Tashkent',
    );

    expect(request.scheduledAt, '2001-01-01T00:00:00+05:00');
  });

  test('only a Scheduled Blitz at the exact instant is a local no-op', () {
    final request = TeacherBlitzScheduleRequest.fromWallClock(
      const InstitutionWallClock(
        year: 2026,
        month: 9,
        day: 30,
        hour: 9,
        minute: 0,
      ),
      'Asia/Tashkent',
    );
    final instant = DateTime.utc(2026, 9, 30, 4);

    expect(
      request.isNoOpFor(
        teacherBlitz(
          status: TeacherBlitzStatus.scheduled,
          scheduledAt: instant,
        ),
      ),
      isTrue,
    );
    expect(
      request.isNoOpFor(
        teacherBlitz(
          status: TeacherBlitzStatus.scheduled,
          scheduledAt: instant.add(const Duration(minutes: 1)),
        ),
      ),
      isFalse,
    );
    expect(
      request.isNoOpFor(
        teacherBlitz(status: TeacherBlitzStatus.draft, scheduledAt: instant),
      ),
      isFalse,
    );
  });

  test('a confirmed schedule needs Scheduled status at the same instant', () {
    final request = TeacherBlitzScheduleRequest.fromWallClock(
      const InstitutionWallClock(
        year: 2026,
        month: 9,
        day: 30,
        hour: 9,
        minute: 0,
      ),
      'Asia/Tashkent',
    );

    expect(
      request.isConfirmedBy(
        teacherBlitz(
          status: TeacherBlitzStatus.scheduled,
          scheduledAt: DateTime.utc(2026, 9, 30, 4),
        ),
      ),
      isTrue,
    );
    expect(
      request.isConfirmedBy(
        teacherBlitz(
          status: TeacherBlitzStatus.draft,
          scheduledAt: DateTime.utc(2026, 9, 30, 4),
        ),
      ),
      isFalse,
    );
    expect(
      request.isConfirmedBy(
        teacherBlitz(
          status: TeacherBlitzStatus.scheduled,
          scheduledAt: DateTime.utc(2026, 9, 30, 5),
        ),
      ),
      isFalse,
    );
  });
}
