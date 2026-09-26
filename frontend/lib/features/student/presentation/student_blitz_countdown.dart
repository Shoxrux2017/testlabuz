import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/student_blitz.dart';
import 'student_blitz_formatters.dart';

/// Live countdown anchored to a server `remaining_seconds` snapshot.
///
/// Remaining time is always recomputed from the anchor's monotonic adoption
/// clock, never from the device wall clock, from when the countdown was
/// drawn, or by counting timer callbacks, so a changed device clock or a
/// paused event loop cannot grant extra time. It is presentation only: the
/// server decides every execution outcome.
class StudentBlitzCountdown extends StatefulWidget {
  const StudentBlitzCountdown({
    required this.anchor,
    required this.label,
    this.onExpired,
    super.key,
  });

  final StudentBlitzCountdownAnchor anchor;
  final String label;

  /// Called once per anchor when the local display reaches zero.
  final ValueChanged<StudentBlitzCountdownAnchor>? onExpired;

  @override
  State<StudentBlitzCountdown> createState() => _StudentBlitzCountdownState();
}

class _StudentBlitzCountdownState extends State<StudentBlitzCountdown> {
  /// The first of equal anchors; a later equal one never restarts its clock.
  late StudentBlitzCountdownAnchor _active;
  Timer? _ticker;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _active = widget.anchor;
    _anchor();
  }

  @override
  void didUpdateWidget(StudentBlitzCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.anchor != _active) {
      _active = widget.anchor;
      _anchor();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _anchor() {
    _ticker?.cancel();
    _remaining = _currentRemaining();
    if (_remaining == 0) {
      // Never report during build; the owner may start a server read.
      final anchor = _active;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_active, anchor)) {
          widget.onExpired?.call(anchor);
        }
      });
      return;
    }
    // The timer only schedules recomputation; it is not the time source.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  int _currentRemaining() {
    final remaining =
        _active.remainingSeconds - _active.adoptionClock.elapsed.inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  void _tick() {
    if (!mounted) {
      return;
    }
    final remaining = _currentRemaining();
    if (remaining != _remaining) {
      setState(() => _remaining = remaining);
    }
    if (remaining == 0) {
      // Cancelling first makes the report exactly once per anchor.
      _ticker?.cancel();
      widget.onExpired?.call(_active);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finalMinute = _remaining <= 60;
    // Exposes current words without a live region, so screen readers are not
    // interrupted every second.
    return Semantics(
      key: const Key('studentBlitzCountdown'),
      label: '${widget.label}: ${formatStudentBlitzDurationWords(_remaining)}',
      excludeSemantics: true,
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(finalMinute ? Icons.hourglass_bottom : Icons.timer_outlined),
          Text(widget.label, style: theme.textTheme.titleMedium),
          Text(
            formatStudentBlitzCountdown(_remaining),
            key: const Key('studentBlitzCountdownValue'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: finalMinute ? FontWeight.w800 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
