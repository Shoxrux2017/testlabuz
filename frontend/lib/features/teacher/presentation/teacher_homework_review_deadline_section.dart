import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../core/time/institution_timezone.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_homework_review_deadline_controller.dart';
import '../application/teacher_homework_review_deadline_state.dart';
import '../application/teacher_homework_route_mutation_activity.dart';
import '../application/teacher_homework_route_target.dart';
import '../application/teacher_session_key.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_homework_mutation.dart';
import 'teacher_date_picker_range.dart';
import 'teacher_homework_formatters.dart';

/// Sets, changes or clears the Homework review deadline on desktop (`S09-D2`).
class TeacherHomeworkReviewDeadlineSection extends ConsumerStatefulWidget {
  const TeacherHomeworkReviewDeadlineSection({
    required this.target,
    required this.homework,
    required this.enabled,
    required this.isCurrentTarget,
    super.key,
  });

  final TeacherHomeworkRouteTarget target;
  final TeacherHomework homework;

  /// False while the detail refreshes; the route lease also disables actions.
  final bool enabled;
  final bool Function(TeacherHomeworkRouteTarget target) isCurrentTarget;

  @override
  ConsumerState<TeacherHomeworkReviewDeadlineSection> createState() =>
      _TeacherHomeworkReviewDeadlineSectionState();
}

class _TeacherHomeworkReviewDeadlineSectionState
    extends ConsumerState<TeacherHomeworkReviewDeadlineSection> {
  String? _localError;

  @override
  Widget build(BuildContext context) {
    final provider = teacherHomeworkReviewDeadlineControllerProvider(
      widget.target,
    );
    final mutation = ref.watch(provider);
    final activity = ref.watch(
      teacherHomeworkRouteMutationActivityProvider(widget.target),
    );
    final homework = widget.homework;
    final hasDeadline = homework.reviewDueAt != null;
    final actionsEnabled = widget.enabled && !activity.isActive;
    // A new local picker error replaces an earlier server outcome.
    final feedback =
        _localError ??
        (mutation.status ==
                    TeacherHomeworkReviewDeadlineStatus.definiteFailure ||
                mutation.status ==
                    TeacherHomeworkReviewDeadlineStatus.outcomeReview
            ? mutation.feedback
            : null);

    return Card(
      key: const Key('teacherHomeworkReviewDeadlineSection'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Review deadline',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              hasDeadline
                  ? formatTeacherHomeworkReviewDeadline(
                      homework.reviewDueAt,
                      homework.institutionTimezone,
                    )
                  : 'No review deadline.',
              key: const Key('teacherHomeworkReviewDeadlineValue'),
            ),
            const SizedBox(height: 4),
            const Text(
              'A reminder for checking submissions. It never changes scores.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('teacherHomeworkReviewDeadlineSetButton'),
                  onPressed: actionsEnabled ? _choose : null,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    hasDeadline
                        ? 'Change review deadline'
                        : 'Set review deadline',
                  ),
                ),
                if (hasDeadline)
                  TextButton.icon(
                    key: const Key('teacherHomeworkReviewDeadlineClearButton'),
                    onPressed: actionsEnabled ? _clear : null,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            if (mutation.isBusy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                key: Key('teacherHomeworkReviewDeadlineProgress'),
                semanticsLabel: 'Updating review deadline',
              ),
            ],
            if (feedback != null) ...[
              const SizedBox(height: 12),
              Text(
                feedback,
                key: const Key('teacherHomeworkReviewDeadlineFeedback'),
              ),
            ],
            if (mutation.canCheckCurrent) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key(
                    'teacherHomeworkReviewDeadlineCheckCurrentButton',
                  ),
                  onPressed: ref.read(provider.notifier).checkCurrentHomework,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check current Homework'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _choose() async {
    final originatingSessionKey = _eligibleDesktopSessionKey();
    if (originatingSessionKey == null) {
      return;
    }
    setState(() => _localError = null);
    final timezone = widget.homework.institutionTimezone;
    final InstitutionWallClock initial;
    try {
      final current = InstitutionTimezone.instantToWallClock(
        widget.homework.reviewDueAt ?? DateTime.now().toUtc(),
        timezone,
      );
      if (current == null) {
        throw const InstitutionTimezoneException(
          InstitutionTimezoneFailureReason.unknownTimezone,
        );
      }
      initial = current;
    } on InstitutionTimezoneException {
      setState(() => _localError = 'The Institution timezone is unavailable.');
      return;
    }

    final range = teacherDatePickerRange(initial.date);
    final date = await showDatePicker(
      context: context,
      initialDate: initial.date,
      firstDate: range.first,
      lastDate: range.last,
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (time == null || !mounted) {
      return;
    }

    final TeacherHomeworkReviewDueAtRequest request;
    try {
      request = TeacherHomeworkReviewDueAtRequest.fromWallClock(
        InstitutionWallClock(
          year: date.year,
          month: date.month,
          day: date.day,
          hour: time.hour,
          minute: time.minute,
        ),
        timezone,
      );
    } on InstitutionTimezoneException catch (exception) {
      setState(
        () => _localError =
            exception.reason ==
                InstitutionTimezoneFailureReason.nonexistentLocalTime
            ? 'This local time does not exist in the Institution timezone.'
            : 'The Institution timezone is unavailable.',
      );
      return;
    }
    await _submit(request, originatingSessionKey);
  }

  Future<void> _clear() async {
    final originatingSessionKey = _eligibleDesktopSessionKey();
    if (originatingSessionKey == null) {
      return;
    }
    setState(() => _localError = null);
    await _submit(
      TeacherHomeworkReviewDueAtRequest.fromWallClock(
        null,
        widget.homework.institutionTimezone,
      ),
      originatingSessionKey,
    );
  }

  Future<void> _submit(
    TeacherHomeworkReviewDueAtRequest request,
    TeacherSessionKey originatingSessionKey,
  ) async {
    if (!mounted ||
        !widget.isCurrentTarget(widget.target) ||
        _eligibleDesktopSessionKey() != originatingSessionKey) {
      return;
    }
    await ref
        .read(
          teacherHomeworkReviewDeadlineControllerProvider(
            widget.target,
          ).notifier,
        )
        .submit(request);
  }

  TeacherSessionKey? _eligibleDesktopSessionKey() {
    final sessionKey = TeacherSessionSnapshot.fromSession(
      ref.read(authSessionControllerProvider),
      ref.read(appDeviceSurfaceProvider),
    ).eligibleKey;
    return sessionKey?.surface == AppDeviceSurface.desktop ? sessionKey : null;
  }
}
