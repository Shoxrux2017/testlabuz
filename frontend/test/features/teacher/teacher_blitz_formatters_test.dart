import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/teacher/domain/teacher_blitz.dart';
import 'package:testlabuz_client/features/teacher/presentation/teacher_blitz_formatters.dart';

void main() {
  test('labels every Blitz status, assignment, and timer snapshot', () {
    expect(TeacherBlitzStatus.values.map(teacherBlitzStatusLabel), [
      'Draft',
      'Scheduled',
      'Active',
      'Closed',
      'Archived',
    ]);
    expect(TeacherBlitzAssignmentMode.values.map(teacherBlitzAssignmentLabel), [
      'Whole group',
      'Selected students',
    ]);
    expect(
      teacherBlitzTimerModeLabel(null),
      'Not snapshotted until activation',
    );
    expect(
      teacherBlitzTimerModeLabel(TeacherBlitzTimerStartMode.synchronized),
      'Synchronized',
    );
    expect(
      teacherBlitzTimerModeLabel(TeacherBlitzTimerStartMode.individual),
      'Individual',
    );
  });

  test('formats whole durations without rounding away seconds', () {
    expect(formatTeacherBlitzDuration(1), '1 sec');
    expect(formatTeacherBlitzDuration(45), '45 sec');
    expect(formatTeacherBlitzDuration(60), '1 min');
    expect(formatTeacherBlitzDuration(90), '1 min 30 sec');
    expect(formatTeacherBlitzDuration(600), '10 min');
    expect(formatTeacherBlitzDuration(3600), '1 hr');
    expect(formatTeacherBlitzDuration(3601), '1 hr 1 sec');
    expect(formatTeacherBlitzDuration(3661), '1 hr 1 min 1 sec');
    expect(formatTeacherBlitzDuration(90000), '25 hr');
    expect(() => formatTeacherBlitzDuration(0), throwsArgumentError);
  });

  test('formats the schedule only in the Institution timezone', () {
    expect(
      formatTeacherBlitzScheduledAt(null, 'Asia/Tashkent'),
      'Not scheduled',
    );
    expect(
      formatTeacherBlitzScheduledAt(
        DateTime.utc(2026, 9, 18, 4, 0, 0, 123, 456),
        'Asia/Tashkent',
      ),
      '2026-09-18 09:00',
    );
    expect(
      formatTeacherBlitzScheduledAt(
        DateTime.utc(2026, 9, 18, 4),
        'Invalid/Zone',
      ),
      'Institution timezone unavailable',
    );
  });
}
