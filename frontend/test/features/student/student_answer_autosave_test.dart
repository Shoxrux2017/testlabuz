import 'package:flutter_test/flutter_test.dart';
import 'package:testlabuz_client/features/student/application/student_answer_autosave.dart';

import 'student_autosave_test_support.dart';

void main() {
  late FakeAutosaveTimers timers;
  late StudentAnswerAutosave autosave;
  late int dueSignals;

  setUp(() {
    timers = FakeAutosaveTimers();
    dueSignals = 0;
    autosave = StudentAnswerAutosave(timers.factory, () => dueSignals++);
  });

  test('a change becomes due one second after the last change', () {
    autosave.changed('a');
    timers.elapse(const Duration(milliseconds: 600));
    autosave.changed('a');
    timers.elapse(const Duration(milliseconds: 999));
    expect(autosave.next((_) => true), isNull);
    expect(dueSignals, 0);
    timers.elapse(const Duration(milliseconds: 1));
    expect(autosave.next((_) => true), 'a');
    expect(dueSignals, 1);
  });

  test('due Questions are offered in the order they first became dirty', () {
    autosave
      ..changed('b')
      ..changed('a');
    timers.elapse(const Duration(milliseconds: 500));
    autosave.changed('b');
    timers.elapse(const Duration(seconds: 1));
    expect(autosave.next((_) => true), 'b');
    expect(autosave.next((id) => id != 'b'), 'a');
  });

  test('dueNow skips the wait of one Question only', () {
    autosave
      ..changed('a')
      ..changed('b')
      ..dueNow('b');
    expect(autosave.next((_) => true), 'b');
    expect(dueSignals, 1);
    expect(autosave.next((id) => id == 'a'), isNull);
    expect(timers.pendingCount, 1);
    autosave.dueNow('explicit');
    expect(autosave.next((id) => id == 'explicit'), 'explicit');
  });

  test(
    'a sending Question is due again only if it is still dirty afterwards',
    () {
      autosave
        ..changed('a')
        ..dueNow('a')
        ..sending('a');
      expect(autosave.next((_) => true), isNull);
      autosave.finished('a', dirty: true);
      expect(autosave.next((_) => true), 'a');
      autosave
        ..sending('a')
        ..finished('a', dirty: false);
      expect(autosave.next((_) => true), isNull);
    },
  );

  test(
    'a Question undone during its save is due again if the save left it dirty',
    () {
      autosave
        ..changed('a')
        ..dueNow('a')
        ..sending('a')
        // The draft went back to the server value, so it was clean.
        ..forget('a')
        // The save stored the other value, so the draft is dirty again.
        ..finished('a', dirty: true);
      expect(autosave.next((_) => true), 'a');
      expect(dueSignals, 2);
    },
  );

  test('a change during the save keeps waiting for its own debounce', () {
    autosave
      ..changed('a')
      ..dueNow('a')
      ..sending('a')
      ..changed('a')
      ..finished('a', dirty: true);
    expect(autosave.next((_) => true), isNull);
    timers.elapse(const Duration(seconds: 1));
    expect(autosave.next((_) => true), 'a');
  });

  test('a rejected Question is not due again until it changes', () {
    autosave
      ..changed('a')
      ..dueNow('a')
      ..sending('a')
      ..rejected('a')
      ..dueNow('a');
    expect(autosave.next((_) => true), isNull);
    autosave.changed('a');
    timers.elapse(const Duration(seconds: 1));
    expect(autosave.next((_) => true), 'a');
  });

  test('recovery waits 2, 4, 8, 16 and then every 30 seconds', () {
    var recoveries = 0;
    for (final expected in [2, 4, 8, 16, 30, 30]) {
      autosave.scheduleRecovery(() => recoveries++);
      expect(timers.pendingDelays, [Duration(seconds: expected)]);
      timers.elapse(Duration(seconds: expected));
    }
    expect(recoveries, 6);
    autosave
      ..resetRecovery()
      ..scheduleRecovery(() => recoveries++);
    expect(timers.pendingDelays, [const Duration(seconds: 2)]);
  });

  test('clear cancels every timer and forgets every Question', () {
    var recoveries = 0;
    autosave
      ..changed('a')
      ..changed('b')
      ..dueNow('b')
      ..scheduleRecovery(() => recoveries++)
      ..clear();
    expect(timers.pendingCount, 0);
    expect(autosave.next((_) => true), isNull);
    timers.elapse(const Duration(minutes: 1));
    expect(autosave.next((_) => true), isNull);
    expect(recoveries, 0);
    expect(dueSignals, 1);
  });
}
