import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/domain/student_blitz.dart';
import 'package:testlabuz_client/features/student/presentation/student_blitz_countdown.dart';
import 'package:testlabuz_client/features/student/presentation/student_blitz_formatters.dart';

import 'student_blitz_test_support.dart';

void main() {
  test('countdown text is mm:ss below one hour and h:mm:ss above', () {
    expect(formatStudentBlitzCountdown(300), '05:00');
    expect(formatStudentBlitzCountdown(61), '01:01');
    expect(formatStudentBlitzCountdown(0), '00:00');
    expect(formatStudentBlitzCountdown(3599), '59:59');
    expect(formatStudentBlitzCountdown(3600), '1:00:00');
    expect(formatStudentBlitzCountdown(3661), '1:01:01');
    expect(formatStudentBlitzCountdown(-5), '00:00');
  });

  test('accessible remaining text uses words, not a clock face', () {
    expect(formatStudentBlitzDurationWords(300), '5 minutes');
    expect(formatStudentBlitzDurationWords(61), '1 minute 1 second');
    expect(formatStudentBlitzDurationWords(3661), '1 hour 1 minute 1 second');
    expect(formatStudentBlitzDurationWords(0), '0 seconds');
  });

  test('durations are compact', () {
    expect(formatStudentBlitzDuration(600), '10 min');
    expect(formatStudentBlitzDuration(252), '4 min 12 sec');
    expect(formatStudentBlitzDuration(45), '45 sec');
    expect(formatStudentBlitzDuration(3661), '1 h 1 min 1 sec');
    expect(formatStudentBlitzDuration(0), '0 sec');
  });

  testWidgets('counts down from server remaining seconds by elapsed time', (
    tester,
  ) async {
    final expired = <StudentBlitzCountdownAnchor>[];
    await _pump(tester, _anchor(300), onExpired: expired.add);
    expect(_value(tester), '05:00');
    await tester.pump(const Duration(milliseconds: 999));
    expect(_value(tester), '05:00');
    await tester.pump(const Duration(milliseconds: 1));
    expect(_value(tester), '04:59');
    // One delayed frame after a paused event loop skips straight ahead.
    await tester.pump(const Duration(seconds: 119));
    expect(_value(tester), '03:00');
    expect(expired, isEmpty);
  });

  testWidgets('an hour-long anchor uses the hour form', (tester) async {
    await _pump(tester, _anchor(3661));
    expect(_value(tester), '1:01:01');
    await tester.pump(const Duration(seconds: 62));
    expect(_value(tester), '59:59');
  });

  testWidgets('zero fires onExpired once and never shows negative time', (
    tester,
  ) async {
    final expired = <StudentBlitzCountdownAnchor>[];
    final anchor = _anchor(2);
    await _pump(tester, anchor, onExpired: expired.add);
    await tester.pump(const Duration(seconds: 2));
    expect(_value(tester), '00:00');
    expect(expired, [anchor]);
    await tester.pump(const Duration(seconds: 30));
    expect(_value(tester), '00:00');
    expect(expired, [anchor]);
  });

  testWidgets('an unrelated rebuild with the same anchor keeps counting', (
    tester,
  ) async {
    await _pump(tester, _anchor(300));
    await tester.pump(const Duration(seconds: 10));
    await _pump(tester, _anchor(300), label: 'Rebuilt label');
    expect(find.text('Rebuilt label'), findsOneWidget);
    expect(_value(tester), '04:50');
  });

  testWidgets('a newer server snapshot re-anchors and re-arms expiry', (
    tester,
  ) async {
    final expired = <StudentBlitzCountdownAnchor>[];
    final first = _anchor(1);
    await _pump(tester, first, onExpired: expired.add);
    await tester.pump(const Duration(seconds: 1));
    expect(expired, [first]);
    final second = _anchor(120, serverNow: DateTime.utc(2026, 9, 17, 12, 3));
    await _pump(tester, second, onExpired: expired.add);
    expect(_value(tester), '02:00');
    await tester.pump(const Duration(seconds: 120));
    expect(expired, [first, second]);
  });

  testWidgets('an anchor already at zero reports expiry after the frame', (
    tester,
  ) async {
    final expired = <StudentBlitzCountdownAnchor>[];
    final anchor = _anchor(0);
    await _pump(tester, anchor, onExpired: expired.add);
    await tester.pump();
    expect(_value(tester), '00:00');
    expect(expired, [anchor]);
  });

  testWidgets('screen readers get words without a per-second live region', (
    tester,
  ) async {
    await _pump(tester, _anchor(61));
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('studentBlitzCountdown')),
    );
    expect(semantics.properties.label, 'Time remaining: 1 minute 1 second');
    expect(semantics.properties.liveRegion, isNot(isTrue));
  });

  testWidgets('the last minute changes the icon, not only the color', (
    tester,
  ) async {
    await _pump(tester, _anchor(61));
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.hourglass_bottom), findsOneWidget);
  });
}

StudentBlitzCountdownAnchor _anchor(int remaining, {DateTime? serverNow}) =>
    StudentBlitzCountdownAnchor(
      subjectId: studentBlitzAttemptId,
      deadlineAt: DateTime.utc(2026, 9, 17, 12, 5),
      serverNow: serverNow ?? DateTime.utc(2026, 9, 17, 12),
      remainingSeconds: remaining,
    );

Future<void> _pump(
  WidgetTester tester,
  StudentBlitzCountdownAnchor anchor, {
  String label = 'Time remaining',
  ValueChanged<StudentBlitzCountdownAnchor>? onExpired,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studentBlitzStopwatchFactoryProvider.overrideWithValue(
          () => tester.binding.clock.stopwatch(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: StudentBlitzCountdown(
            anchor: anchor,
            label: label,
            onExpired: onExpired,
          ),
        ),
      ),
    ),
  );
}

String _value(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('studentBlitzCountdownValue')))
    .data!;
