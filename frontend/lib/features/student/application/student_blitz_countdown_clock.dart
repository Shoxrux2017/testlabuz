import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monotonic elapsed-time source for countdown baselines. Controllers start
/// one when they adopt a server snapshot; widget tests substitute the fake
/// clock.
final studentBlitzStopwatchFactoryProvider = Provider<Stopwatch Function()>(
  (ref) => Stopwatch.new,
);
