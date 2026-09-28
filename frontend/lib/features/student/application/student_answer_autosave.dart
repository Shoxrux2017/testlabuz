import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef StudentAutosaveTimerFactory =
    Timer Function(Duration duration, void Function() callback);

final studentAutosaveTimerFactoryProvider =
    Provider<StudentAutosaveTimerFactory>((ref) => Timer.new);

/// Decides when each changed Question is due for its automatic save.
///
/// A Question becomes due one second after its last change, or at once when
/// asked. Due Questions are offered in the order they first became dirty. The
/// owning controller sends them one at a time and reports each outcome.
class StudentAnswerAutosave {
  StudentAnswerAutosave(this._startTimer, this._onDue);

  static const debounce = Duration(milliseconds: 1000);
  static const _recoveryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  final StudentAutosaveTimerFactory _startTimer;
  final void Function() _onDue;

  // Insertion order is the first-dirty order.
  final _tracked = <String>{};
  final _due = <String>{};
  final _rejected = <String>{};
  final _debounces = <String, Timer>{};
  Timer? _recovery;
  var _recoveryStep = 0;

  bool isTracked(String id) => _tracked.contains(id);

  void changed(String id) {
    _rejected.remove(id);
    _tracked.add(id);
    _due.remove(id);
    _debounces.remove(id)?.cancel();
    _debounces[id] = _startTimer(debounce, () {
      _debounces.remove(id);
      _markDue(id);
    });
  }

  /// Makes [id] due at once; an explicit request also starts tracking it.
  void dueNow(String id) {
    _debounces.remove(id)?.cancel();
    _tracked.add(id);
    _markDue(id);
  }

  void allDueNow() {
    for (final id in _tracked.toList()) {
      dueNow(id);
    }
  }

  String? next(bool Function(String id) canSend) {
    for (final id in _tracked) {
      if (_due.contains(id) && canSend(id)) return id;
    }
    return null;
  }

  void sending(String id) => _due.remove(id);

  void finished(String id, {required bool dirty}) {
    if (!dirty) {
      forget(id);
    } else if (!_debounces.containsKey(id)) {
      _markDue(id);
    }
  }

  void rejected(String id) {
    _due.remove(id);
    _debounces.remove(id)?.cancel();
    if (_tracked.contains(id)) _rejected.add(id);
  }

  void forget(String id) {
    _tracked.remove(id);
    _due.remove(id);
    _rejected.remove(id);
    _debounces.remove(id)?.cancel();
  }

  void scheduleRecovery(void Function() recover) {
    _recovery?.cancel();
    final delay = _recoveryDelays[_recoveryStep];
    if (_recoveryStep < _recoveryDelays.length - 1) _recoveryStep += 1;
    _recovery = _startTimer(delay, () {
      _recovery = null;
      recover();
    });
  }

  void resetRecovery() {
    _recovery?.cancel();
    _recovery = null;
    _recoveryStep = 0;
  }

  void clear() {
    for (final timer in _debounces.values) {
      timer.cancel();
    }
    _debounces.clear();
    _tracked.clear();
    _due.clear();
    _rejected.clear();
    resetRecovery();
  }

  void _markDue(String id) {
    if (!_tracked.contains(id) || _rejected.contains(id)) return;
    _due.add(id);
    _onDue();
  }
}
