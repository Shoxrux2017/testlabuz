import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/student_blitz_attempt_start_controller.dart';
import '../application/student_blitz_attempt_start_state.dart';
import '../application/student_blitz_detail_controller.dart';
import '../application/student_blitz_detail_state.dart';
import '../domain/student_blitz.dart';
import '../domain/student_blitz_attempt.dart';
import '../domain/student_blitz_route_target.dart';
import 'student_blitz_attempt_shell.dart';
import 'student_blitz_countdown.dart';
import 'student_blitz_formatters.dart';

/// Pre-Start Blitz detail and, after an explicit successful Start/Resume in
/// this route session, the execution shell on the same route.
class StudentBlitzDetailScreen extends ConsumerStatefulWidget {
  const StudentBlitzDetailScreen({required this.target, super.key});

  final StudentBlitzRouteTarget target;

  @override
  ConsumerState<StudentBlitzDetailScreen> createState() =>
      _StudentBlitzDetailScreenState();
}

class _StudentBlitzDetailScreenState
    extends ConsumerState<StudentBlitzDetailScreen> {
  /// The pre-Start class countdown that reached zero locally. Its
  /// reconciliation read moves detail out of `data`, which removes Start
  /// until a newer server snapshot arrives.
  StudentBlitzCountdownAnchor? _expiredPreStartAnchor;

  StudentBlitzRouteTarget get _target => widget.target;

  @override
  Widget build(BuildContext context) {
    final detailProvider = studentBlitzDetailControllerProvider(_target);
    final startProvider = studentBlitzAttemptStartControllerProvider(_target);
    final detail = ref.watch(detailProvider);
    final start = ref.watch(startProvider);
    ref.listen(startProvider, (_, next) {
      if (next.feedback == null) {
        return;
      }
      final feedback = ref.read(startProvider.notifier).consumeFeedback();
      if (feedback != null && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(studentBlitzStartFeedbackMessage(feedback))),
        );
      }
    });
    final timezone =
        ref.watch(authSessionControllerProvider).user?.institution?.timezone ??
        '';
    final executing =
        start.status == StudentBlitzAttemptStartStatus.active &&
        start.attempt != null &&
        start.executionAnchor != null;
    final guardsLeave = executing && !start.isReconcilingExpiry;

    return PopScope(
      canPop: !guardsLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _leave(confirm: true);
        }
      },
      child: Scaffold(
        key: const Key('studentBlitzDetailScreen'),
        appBar: AppBar(
          title: const Text('Blitz'),
          leading: IconButton(
            key: const Key('studentBlitzBackButton'),
            tooltip: 'Back to Topic',
            onPressed: () => _leave(confirm: guardsLeave),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: executing
              ? StudentBlitzAttemptShell(
                  state: start,
                  detail: detail,
                  institutionTimezone: timezone,
                  onExpired: ref
                      .read(startProvider.notifier)
                      .markExecutionExpired,
                  onRefresh: ref.read(detailProvider.notifier).reconcile,
                  onLeave: () => _leave(confirm: guardsLeave),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showsStartStatus(start, detail))
                      _StartStatus(
                        state: start,
                        onRetry: ref.read(startProvider.notifier).retry,
                      ),
                    Expanded(child: _detailBody(detail, start)),
                  ],
                ),
        ),
      ),
    );
  }

  bool _showsStartStatus(
    StudentBlitzAttemptStartState start,
    StudentBlitzDetailState detail,
  ) {
    final hasOwnView =
        detail.status == StudentBlitzDetailStatus.notActive ||
        detail.status == StudentBlitzDetailStatus.timeExpired ||
        detail.status == StudentBlitzDetailStatus.notFound;
    return switch (start.status) {
      StudentBlitzAttemptStartStatus.submitting ||
      StudentBlitzAttemptStartStatus.uncertain => true,
      StudentBlitzAttemptStartStatus.failure ||
      StudentBlitzAttemptStartStatus.terminal => !hasOwnView,
      StudentBlitzAttemptStartStatus.idle ||
      StudentBlitzAttemptStartStatus.active => false,
    };
  }

  Widget _detailBody(
    StudentBlitzDetailState detail,
    StudentBlitzAttemptStartState start,
  ) {
    final controller = ref.read(
      studentBlitzDetailControllerProvider(_target).notifier,
    );
    return switch (detail.status) {
      StudentBlitzDetailStatus.initial ||
      StudentBlitzDetailStatus.loading => const Center(
        child: CircularProgressIndicator(
          key: Key('studentBlitzDetailLoading'),
          semanticsLabel: 'Loading Blitz',
        ),
      ),
      StudentBlitzDetailStatus.notFound => _BlitzUnavailable(
        key: const Key('studentBlitzUnavailable'),
        title: 'Blitz unavailable',
        message: 'This Blitz is no longer available.',
        onBack: () => _leave(confirm: false),
      ),
      StudentBlitzDetailStatus.notActive => _BlitzUnavailable(
        key: const Key('studentBlitzNotActive'),
        title: 'Blitz not active',
        message: 'This Blitz is no longer active.',
        onBack: () => _leave(confirm: false),
        onRefresh: controller.refresh,
      ),
      StudentBlitzDetailStatus.timeExpired => _BlitzUnavailable(
        key: const Key('studentBlitzTimeExpired'),
        title: 'Time expired',
        message: 'The Blitz time has expired.',
        onBack: () => _leave(confirm: false),
        onRefresh: controller.refresh,
      ),
      StudentBlitzDetailStatus.error => _BlitzUnavailable(
        key: const Key('studentBlitzDetailError'),
        title: 'Unable to load Blitz',
        message: studentBlitzDetailFailureMessage(detail.failure!),
        onBack: () => _leave(confirm: false),
        onRefresh: controller.retry,
        refreshLabel: 'Retry',
      ),
      StudentBlitzDetailStatus.data ||
      StudentBlitzDetailStatus.refreshing => _PreStartContent(
        blitz: detail.blitz!,
        refreshing: detail.status == StudentBlitzDetailStatus.refreshing,
        busy: !start.acceptsNewRequest,
        expiredPreStartAnchor: _expiredPreStartAnchor,
        onRefresh: controller.refresh,
        onClassTimeExpired: (anchor) {
          setState(() => _expiredPreStartAnchor = anchor);
          controller.reconcileAfterLocalExpiry();
        },
        action: detail.status == StudentBlitzDetailStatus.data
            ? _action(detail.blitz!, start)
            : null,
      ),
    };
  }

  Widget? _action(
    StudentBlitzDetail blitz,
    StudentBlitzAttemptStartState start,
  ) {
    if (!start.acceptsNewRequest) {
      return null;
    }
    return switch (studentBlitzExecutionAction(blitz.attempts)) {
      StudentBlitzExecutionAction.resume => FilledButton.icon(
        key: const Key('studentBlitzResumeButton'),
        // The Attempt already exists and Resume never resets its timer.
        onPressed: () => _start(StudentBlitzExecutionAction.resume),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Resume Blitz'),
      ),
      StudentBlitzExecutionAction.startReplacement => FilledButton.icon(
        key: const Key('studentBlitzStartAdditionalButton'),
        onPressed: () => _confirmReplacement(blitz),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start additional attempt'),
      ),
      StudentBlitzExecutionAction.startNormal => FilledButton.icon(
        key: const Key('studentBlitzStartButton'),
        onPressed: () => _confirmStart(blitz),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Blitz'),
      ),
      null => null,
    };
  }

  Future<void> _confirmStart(StudentBlitzDetail blitz) async {
    final synchronized =
        blitz.timing.mode == StudentBlitzTimerMode.synchronized;
    final confirmed = await _confirm(
      key: const Key('studentBlitzStartDialog'),
      title: 'Start Blitz?',
      body: synchronized
          ? 'This Blitz uses a shared class timer.\n'
                'You will receive only the time remaining on the server.\n'
                'Starting does not reset the class timer.'
          : 'Your full Blitz duration starts when the server starts your '
                'attempt.',
      confirmKey: const Key('studentBlitzStartConfirmButton'),
      confirmLabel: 'Start',
    );
    if (confirmed) {
      await _start(StudentBlitzExecutionAction.startNormal);
    }
  }

  Future<void> _confirmReplacement(StudentBlitzDetail blitz) async {
    final synchronized =
        blitz.timing.mode == StudentBlitzTimerMode.synchronized;
    final confirmed = await _confirm(
      key: const Key('studentBlitzStartAdditionalDialog'),
      title: 'Start additional Blitz attempt?',
      body:
          'Your original attempt remains in history.\n'
          'This approved additional attempt receives the full configured '
          'Blitz duration from the moment the server starts it.'
          '${synchronized ? '\nThe original class timer does not restart for other Students.' : ''}',
      confirmKey: const Key('studentBlitzStartAdditionalConfirmButton'),
      confirmLabel: 'Start additional attempt',
    );
    if (confirmed) {
      await _start(StudentBlitzExecutionAction.startReplacement);
    }
  }

  Future<void> _start(StudentBlitzExecutionAction action) async {
    if (!mounted) {
      return;
    }
    await ref
        .read(studentBlitzAttemptStartControllerProvider(_target).notifier)
        .start(action);
  }

  Future<bool> _confirm({
    required Key key,
    required String title,
    required String body,
    required Key confirmKey,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: key,
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: confirmKey,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  /// Leaving never cancels or pauses the server Attempt.
  Future<void> _leave({required bool confirm}) async {
    if (confirm) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('studentBlitzLeaveDialog'),
          title: const Text('Leave Blitz?'),
          content: const Text(
            'Your server timer will continue.\n'
            'You can resume later while the attempt remains active.',
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            FilledButton(
              key: const Key('studentBlitzLeaveConfirmButton'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      if (leave != true) {
        return;
      }
    }
    if (mounted) {
      context.go(AppRoutePaths.studentTopicDetailLocation(_target.topicId));
    }
  }
}

/// The live class countdown anchor for a synchronized normal path that has
/// not started; every other pre-Start shape has no effective countdown.
StudentBlitzCountdownAnchor? studentBlitzPreStartAnchor(
  StudentBlitzDetail blitz,
) {
  final deadline = blitz.timing.deadlineAt;
  final remaining = blitz.timing.remainingSeconds;
  if (blitz.timing.mode != StudentBlitzTimerMode.synchronized ||
      blitz.attempts.normalUsed != 0 ||
      deadline == null ||
      remaining == null) {
    return null;
  }
  return StudentBlitzCountdownAnchor(
    subjectId: blitz.id.toLowerCase(),
    deadlineAt: deadline,
    serverNow: blitz.timing.serverNow,
    remainingSeconds: remaining,
  );
}

class _StartStatus extends StatelessWidget {
  const _StartStatus({required this.state, required this.onRetry});

  final StudentBlitzAttemptStartState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final resume = state.originatingIntent == StudentBlitzAttemptIntent.resume;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.status == StudentBlitzAttemptStartStatus.submitting)
              Wrap(
                key: const Key('studentBlitzStartProgress'),
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: resume
                          ? 'Resuming Blitz, please wait'
                          : 'Starting Blitz, please wait',
                    ),
                  ),
                  Text(resume ? 'Resuming Blitz…' : 'Starting Blitz…'),
                ],
              ),
            if (state.status == StudentBlitzAttemptStartStatus.uncertain) ...[
              const Text(
                'We could not confirm the Blitz attempt state.\n'
                'Retry safely using the same request.',
                key: Key('studentBlitzStartUncertain'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('studentBlitzRetryStartButton'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
            if (state.status == StudentBlitzAttemptStartStatus.failure &&
                state.failure != null)
              Text(
                studentBlitzStartFailureMessage(state.failure!),
                key: const Key('studentBlitzStartFailure'),
                textAlign: TextAlign.center,
              ),
            if (state.status == StudentBlitzAttemptStartStatus.terminal &&
                state.attempt != null)
              Text(
                studentBlitzTerminalAttemptMessage(state.attempt!),
                key: const Key('studentBlitzTerminalAttempt'),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

class _PreStartContent extends StatelessWidget {
  const _PreStartContent({
    required this.blitz,
    required this.refreshing,
    required this.busy,
    required this.expiredPreStartAnchor,
    required this.onRefresh,
    required this.onClassTimeExpired,
    required this.action,
  });

  final StudentBlitzDetail blitz;
  final bool refreshing;
  final bool busy;
  final StudentBlitzCountdownAnchor? expiredPreStartAnchor;
  final VoidCallback onRefresh;
  final ValueChanged<StudentBlitzCountdownAnchor> onClassTimeExpired;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final attempts = blitz.attempts;
    final duration = formatStudentBlitzDuration(blitz.durationSeconds);
    final classAnchor = studentBlitzPreStartAnchor(blitz);
    return SingleChildScrollView(
      key: const Key('studentBlitzDetailScroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (refreshing) ...[
                const LinearProgressIndicator(
                  key: Key('studentBlitzDetailRefreshing'),
                  semanticsLabel: 'Refreshing Blitz',
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          blitz.title,
                          key: const Key('studentBlitzDetailTitle'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Topic: ${blitz.topic.title}'),
                      const SizedBox(height: 12),
                      _EffectiveTiming(
                        blitz: blitz,
                        classAnchor: classAnchor,
                        classTimeExpired:
                            classAnchor != null &&
                            classAnchor == expiredPreStartAnchor,
                        duration: duration,
                        onClassTimeExpired: onClassTimeExpired,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            key: const Key('studentBlitzRefreshButton'),
                            onPressed: refreshing || busy ? null : onRefresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                          ?action,
                        ],
                      ),
                      if (attempts.isFinished) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'You have already finished this Blitz.',
                          key: Key('studentBlitzFinished'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _InformationCard(
                title: 'Blitz information',
                rows: [
                  ('Topic', blitz.topic.title),
                  if (blitz.description case final description?)
                    ('Description', description),
                  ('Student instructions', blitz.studentInstructions),
                  ('Duration', duration),
                  (
                    'Total possible points',
                    formatStudentBlitzPoints(blitz.totalPossiblePoints),
                  ),
                  ('Timer', studentBlitzTimerModeLabel(blitz.timing.mode)),
                ],
              ),
              const SizedBox(height: 12),
              _InformationCard(
                title: 'Attempt information',
                rows: [
                  ('Normal attempt', studentBlitzNormalAttemptLabel(attempts)),
                  (
                    'Additional attempt',
                    studentBlitzAdditionalAttemptLabel(attempts),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EffectiveTiming extends StatelessWidget {
  const _EffectiveTiming({
    required this.blitz,
    required this.classAnchor,
    required this.classTimeExpired,
    required this.duration,
    required this.onClassTimeExpired,
  });

  final StudentBlitzDetail blitz;
  final StudentBlitzCountdownAnchor? classAnchor;
  final bool classTimeExpired;
  final String duration;
  final ValueChanged<StudentBlitzCountdownAnchor> onClassTimeExpired;

  @override
  Widget build(BuildContext context) {
    final attempts = blitz.attempts;
    final anchor = classAnchor;
    if (attempts.replacementAttemptAvailable) {
      return Text(
        'Approved additional attempt available.\n'
        'Your full $duration starts when the server starts it.',
        key: const Key('studentBlitzReplacementTiming'),
      );
    }
    if (anchor != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudentBlitzCountdown(
            anchor: anchor,
            label: 'Class time remaining',
            onExpired: onClassTimeExpired,
          ),
          const SizedBox(height: 4),
          Text(
            classTimeExpired
                ? 'Checking current Blitz time…'
                : 'Starting does not reset this timer.',
            key: const Key('studentBlitzClassTimingNote'),
          ),
        ],
      );
    }
    if (attempts.normalUsed == 0) {
      return Text(
        'Your full $duration starts when the server starts your attempt.',
        key: const Key('studentBlitzIndividualTiming'),
      );
    }
    final remaining = blitz.timing.remainingSeconds;
    if (attempts.inProgressAttemptId != null && remaining != null) {
      return Text(
        'Attempt time remaining at last refresh: '
        '${formatStudentBlitzDuration(remaining)}',
        key: const Key('studentBlitzInProgressTiming'),
      );
    }
    return const SizedBox.shrink();
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            for (final row in rows) ...[
              Text(row.$1, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              SelectableText(row.$2),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _BlitzUnavailable extends StatelessWidget {
  const _BlitzUnavailable({
    required this.title,
    required this.message,
    required this.onBack,
    this.onRefresh,
    this.refreshLabel = 'Refresh',
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;
  final String refreshLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  key: const Key('studentBlitzUnavailableBackButton'),
                  onPressed: onBack,
                  child: const Text('Back to Topic'),
                ),
                if (onRefresh case final refresh?)
                  FilledButton.icon(
                    key: const Key('studentBlitzUnavailableRefreshButton'),
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(refreshLabel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
