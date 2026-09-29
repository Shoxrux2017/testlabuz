import 'dart:async';

import 'package:testlabuz_client/features/student/application/student_answer_autosave.dart';

/// Virtual timers for autosave tests: nothing fires until [elapse] moves the
/// clock past a timer's due time.
class FakeAutosaveTimers {
  final _timers = <_FakeAutosaveTimer>[];
  var _now = Duration.zero;

  StudentAutosaveTimerFactory get factory => (duration, callback) {
    final timer = _FakeAutosaveTimer(_now + duration, callback);
    _timers.add(timer);
    return timer;
  };

  int get pendingCount => _timers.where((timer) => timer.isActive).length;

  List<Duration> get pendingDelays => [
    for (final timer in _timers)
      if (timer.isActive) timer.dueAt - _now,
  ];

  void elapse(Duration duration) {
    final end = _now + duration;
    while (true) {
      final due =
          _timers
              .where((timer) => timer.isActive && timer.dueAt <= end)
              .toList()
            ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      if (due.isEmpty) break;
      final next = due.first;
      _now = next.dueAt;
      next.fire();
    }
    _now = end;
  }
}

class _FakeAutosaveTimer implements Timer {
  _FakeAutosaveTimer(this.dueAt, this._callback);

  final Duration dueAt;
  final void Function() _callback;
  var _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}
