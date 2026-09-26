import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/time/institution_timezone.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_blitz_lifecycle_controller.dart';
import '../application/teacher_blitz_lifecycle_state.dart';
import '../application/teacher_blitz_route_target.dart';
import '../application/teacher_session_key.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_schedule.dart';
import 'teacher_topic_formatters.dart';

/// Opens the Schedule/Reschedule dialog; the POST starts only after confirm.
Future<void> showTeacherBlitzScheduleDialog({
  required BuildContext context,
  required TeacherBlitzRouteTarget target,
  required TeacherBlitz blitz,
  required bool Function(TeacherBlitzRouteTarget target) isCurrentTarget,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => TeacherBlitzScheduleDialog(
      target: target,
      blitz: blitz,
      isCurrentTarget: isCurrentTarget,
    ),
  );
}

class TeacherBlitzScheduleDialog extends ConsumerStatefulWidget {
  const TeacherBlitzScheduleDialog({
    required this.target,
    required this.blitz,
    required this.isCurrentTarget,
    super.key,
  });

  final TeacherBlitzRouteTarget target;
  final TeacherBlitz blitz;
  final bool Function(TeacherBlitzRouteTarget target) isCurrentTarget;

  @override
  ConsumerState<TeacherBlitzScheduleDialog> createState() =>
      _TeacherBlitzScheduleDialogState();
}

class _TeacherBlitzScheduleDialogState
    extends ConsumerState<TeacherBlitzScheduleDialog> {
  TeacherSessionKey? _owner;
  DateTime? _date;
  TimeOfDay? _time;
  String? _error;
  var _submitting = false;
  late final bool _timezoneAvailable;

  bool get _isReschedule => widget.blitz.status == TeacherBlitzStatus.scheduled;

  @override
  void initState() {
    super.initState();
    _owner = _currentSessionOwner();
    final timezone = widget.blitz.institutionTimezone;
    _timezoneAvailable = InstitutionTimezone.tryResolve(timezone) != null;
    if (!_timezoneAvailable) {
      _error = 'Institution timezone is unavailable.';
      return;
    }
    // Prefill only from the server schedule; the device clock is not used.
    final current = InstitutionTimezone.instantToWallClock(
      widget.blitz.scheduledAt,
      timezone,
    );
    if (current != null) {
      _date = current.date;
      _time = TimeOfDay(hour: current.hour, minute: current.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _isReschedule ? 'Reschedule' : 'Schedule';
    final wallClock = _wallClock;

    return AlertDialog(
      key: const Key('teacherBlitzScheduleDialog'),
      title: Text(_isReschedule ? 'Reschedule Blitz' : 'Schedule Blitz'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Institution timezone: ${widget.blitz.institutionTimezone}'),
            const SizedBox(height: 12),
            Text(
              'Planned date/time',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              wallClock == null
                  ? 'Not selected'
                  : formatInstitutionWallClock(wallClock),
              key: const Key('teacherBlitzScheduleValue'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('teacherBlitzScheduleDateButton'),
                  onPressed: _canEdit ? _chooseDate : null,
                  icon: const Icon(Icons.event_outlined),
                  label: const Text('Choose date'),
                ),
                OutlinedButton.icon(
                  key: const Key('teacherBlitzScheduleTimeButton'),
                  onPressed: _canEdit ? _chooseTime : null,
                  icon: const Icon(Icons.schedule_outlined),
                  label: const Text('Choose time'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Scheduling does not activate the Blitz automatically.'),
            if (_submitting) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                key: const Key('teacherBlitzScheduleProgress'),
                semanticsLabel: _isReschedule
                    ? 'Rescheduling Blitz'
                    : 'Scheduling Blitz',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  key: const Key('teacherBlitzScheduleError'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('teacherBlitzScheduleCancelButton'),
          autofocus: true,
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('teacherBlitzScheduleSubmitButton'),
          onPressed: _canEdit && wallClock != null ? _submit : null,
          child: Text(label),
        ),
      ],
    );
  }

  bool get _canEdit => _timezoneAvailable && !_submitting;

  InstitutionWallClock? get _wallClock {
    final date = _date;
    final time = _time;
    if (date == null || time == null) {
      return null;
    }
    return InstitutionWallClock(
      year: date.year,
      month: date.month,
      day: date.day,
      hour: time.hour,
      minute: time.minute,
    );
  }

  Future<void> _chooseDate() async {
    // Only the picker focus; nothing is selected until the Teacher chooses.
    final initial = _date ?? DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      setState(() {
        _date = date;
        _error = null;
      });
    }
  }

  Future<void> _chooseTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (time != null && mounted) {
      setState(() {
        _time = time;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    final wallClock = _wallClock;
    if (wallClock == null || !_isCurrentOwner()) {
      return;
    }
    final TeacherBlitzScheduleRequest request;
    try {
      request = TeacherBlitzScheduleRequest.fromWallClock(
        wallClock,
        widget.blitz.institutionTimezone,
      );
    } on InstitutionTimezoneException catch (error) {
      setState(() {
        _error =
            error.reason == InstitutionTimezoneFailureReason.unknownTimezone
            ? 'Institution timezone is unavailable.'
            : 'This time does not exist in the Institution timezone. Choose '
                  'another time.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final provider = teacherBlitzLifecycleControllerProvider(widget.target);
    await ref.read(provider.notifier).schedule(request);
    if (!mounted) {
      return;
    }
    final outcome = ref.read(provider);
    // A server-rejected time stays editable here; every other outcome is
    // shown by the Blitz lifecycle controls.
    if (outcome.status == TeacherBlitzLifecycleStatus.definiteFailure &&
        outcome.conflictCode == ApiErrorCodes.validationFailed &&
        _isCurrentOwner()) {
      setState(() {
        _submitting = false;
        _error = outcome.notice;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  TeacherSessionKey? _currentSessionOwner() {
    return TeacherSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
  }

  bool _isCurrentOwner() {
    final owner = _owner;
    return mounted &&
        owner != null &&
        _currentSessionOwner() == owner &&
        widget.isCurrentTarget(widget.target);
  }
}
