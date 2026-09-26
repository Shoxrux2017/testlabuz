import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../application/teacher_blitz_attempt_exception_controller.dart';
import '../application/teacher_blitz_attempt_exception_state.dart';
import '../application/teacher_blitz_detail_controller.dart';
import '../application/teacher_blitz_monitoring_controller.dart';
import '../application/teacher_blitz_monitoring_state.dart';
import '../application/teacher_blitz_parent_identity.dart';
import '../application/teacher_blitz_route_target.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_monitoring.dart';
import 'teacher_blitz_attempt_exception_dialog.dart';
import 'teacher_blitz_formatters.dart';
import 'teacher_topic_formatters.dart';

/// Live monitoring of an Active Blitz. Desktop shows full Student rows and
/// additional-attempt grants; mobile shows basic read-only cards.
class TeacherBlitzMonitoringScreen extends ConsumerStatefulWidget {
  const TeacherBlitzMonitoringScreen({required this.target, super.key});

  final TeacherBlitzRouteTarget target;

  @override
  ConsumerState<TeacherBlitzMonitoringScreen> createState() =>
      _TeacherBlitzMonitoringScreenState();
}

class _TeacherBlitzMonitoringScreenState
    extends ConsumerState<TeacherBlitzMonitoringScreen> {
  late TeacherBlitzMonitoringController _monitoring;
  late final AppLifecycleListener _appLifecycle;

  @override
  void initState() {
    super.initState();
    _bindTarget();
    _appLifecycle = AppLifecycleListener(
      onStateChange: (state) =>
          _monitoring.setAppResumed(state == AppLifecycleState.resumed),
    );
  }

  @override
  void didUpdateWidget(covariant TeacherBlitzMonitoringScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target == widget.target) {
      return;
    }
    final previous = _monitoring;
    _bindTarget();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previous.leaveLiveRoute();
    });
  }

  @override
  void dispose() {
    _appLifecycle.dispose();
    final monitoring = _monitoring;
    // Provider state may not change while the tree is finalizing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      monitoring.leaveLiveRoute();
    });
    super.dispose();
  }

  void _bindTarget() {
    final monitoring = ref.read(
      teacherBlitzMonitoringControllerProvider(widget.target).notifier,
    );
    _monitoring = monitoring;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_monitoring, monitoring)) {
        return;
      }
      final appState = WidgetsBinding.instance.lifecycleState;
      if (appState != null && appState != AppLifecycleState.resumed) {
        monitoring.setAppResumed(false);
      }
      monitoring.enterLiveRoute();
    });
  }

  Future<void> _openGrantDialog(TeacherBlitzMonitoringStudent row) async {
    final grant = ref.read(
      teacherBlitzAttemptExceptionControllerProvider(widget.target).notifier,
    );
    final monitoring = _monitoring;
    final ticket = grant.prepare(row.student.id);
    if (ticket == null) {
      return;
    }
    monitoring.holdForDialog();
    final request = await showTeacherBlitzAttemptExceptionDialog(
      context: context,
      studentName: row.student.fullName,
    );
    if (!mounted) {
      return;
    }
    if (request == null) {
      monitoring.releaseDialogHold();
      return;
    }
    // The grant owns the route before the hold ends, so no poll starts in
    // between; a stale ticket sends nothing.
    final granting = grant.grant(ticket, request);
    monitoring.releaseDialogHold();
    await granting;
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final detailProvider = teacherBlitzDetailControllerProvider(target);
    final detail = ref.watch(detailProvider);
    final identity = teacherBlitzParentIdentity(detail, target);
    final monitoring = ref.watch(
      teacherBlitzMonitoringControllerProvider(target),
    );
    final grant = ref.watch(
      teacherBlitzAttemptExceptionControllerProvider(target),
    );
    final isDesktop =
        ref.watch(appDeviceSurfaceProvider) == AppDeviceSurface.desktop;

    void backToBlitz() {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go(
        AppRoutePaths.teacherBlitzDetailLocation(
          target.topicId,
          target.blitzId,
        ),
      );
    }

    return Scaffold(
      key: const Key('teacherBlitzMonitoringScreen'),
      appBar: AppBar(
        title: const Text('Blitz Monitoring'),
        leading: IconButton(
          key: const Key('teacherBlitzMonitoringBackButton'),
          tooltip: 'Back to Blitz',
          onPressed: backToBlitz,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: switch (identity) {
          TeacherBlitzParentIdentity.checking => const Center(
            child: CircularProgressIndicator(
              key: Key('teacherBlitzMonitoringVerifying'),
              semanticsLabel: 'Verifying Blitz',
            ),
          ),
          TeacherBlitzParentIdentity.notFound => _MonitoringUnavailable(
            onBack: backToBlitz,
          ),
          TeacherBlitzParentIdentity.error => _ParentVerificationError(
            onRetry: ref.read(detailProvider.notifier).retry,
            onBack: backToBlitz,
          ),
          TeacherBlitzParentIdentity.confirmed => _MonitoringContent(
            blitz: detail.blitz!,
            state: monitoring,
            grant: grant,
            isDesktop: isDesktop,
            onRefresh: _monitoring.refresh,
            onBack: backToBlitz,
            onGrant: _openGrantDialog,
            grantController: ref.read(
              teacherBlitzAttemptExceptionControllerProvider(target).notifier,
            ),
          ),
        },
      ),
    );
  }
}

class _MonitoringContent extends StatelessWidget {
  const _MonitoringContent({
    required this.blitz,
    required this.state,
    required this.grant,
    required this.isDesktop,
    required this.onRefresh,
    required this.onBack,
    required this.onGrant,
    required this.grantController,
  });

  /// The confirmed Blitz detail for this exact route target.
  final TeacherBlitz blitz;
  final TeacherBlitzMonitoringState state;
  final TeacherBlitzAttemptExceptionState grant;
  final bool isDesktop;
  final VoidCallback onRefresh;
  final VoidCallback onBack;
  final void Function(TeacherBlitzMonitoringStudent row) onGrant;
  final TeacherBlitzAttemptExceptionController grantController;

  @override
  Widget build(BuildContext context) {
    final monitoring = state.monitoring;
    final timezone = blitz.institutionTimezone;
    final grantOpen = isDesktop && !grant.ownsMonitoring;
    final current = state.currentMonitoring;

    return SingleChildScrollView(
      key: const Key('teacherBlitzMonitoringScroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                blitz: blitz,
                monitoring: monitoring,
                // After a lifecycle end the detail status is stale, not live.
                showStatus: !state.hasEnded,
              ),
              const SizedBox(height: 12),
              // A grant outcome, and its same-key Retry, must stay reachable
              // after live monitoring ends.
              if (isDesktop && (grant.message != null || grant.isBusy)) ...[
                _GrantBanner(grant: grant, controller: grantController),
                const SizedBox(height: 12),
              ],
              if (state.hasEnded)
                _EndedNotice(status: state.status, onBack: onBack)
              else ...[
                _LiveStatus(
                  state: state,
                  refreshEnabled: !state.isLoading && !grant.ownsMonitoring,
                  onRefresh: onRefresh,
                ),
                const SizedBox(height: 12),
                if (monitoring == null)
                  _MonitoringPlaceholder(state: state, onRetry: onRefresh)
                else ...[
                  _TimingCard(monitoring: monitoring, timezone: timezone),
                  const SizedBox(height: 12),
                  _SummaryCard(summary: monitoring.summary),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Text(
                      'Students',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (monitoring.students.isEmpty)
                    const Text(
                      'No Students are assigned to this Blitz.',
                      key: Key('teacherBlitzMonitoringNoStudents'),
                    )
                  else
                    for (final row in monitoring.students) ...[
                      isDesktop
                          ? _DesktopStudentRow(
                              row: row,
                              timezone: timezone,
                              // A UX hint only; the backend decides.
                              onGrant:
                                  grantOpen &&
                                      current != null &&
                                      row.isGrantCandidate
                                  ? () => onGrant(row)
                                  : null,
                            )
                          : _MobileStudentCard(row: row),
                      const SizedBox(height: 8),
                    ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.blitz,
    required this.monitoring,
    required this.showStatus,
  });

  final TeacherBlitz blitz;
  final TeacherBlitzMonitoring? monitoring;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('teacherBlitzMonitoringHeader'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                blitz.title,
                key: const Key('teacherBlitzMonitoringTitle'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (showStatus) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(
                    teacherBlitzStatusLabel(
                      monitoring?.blitz.status ?? blitz.status,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveStatus extends StatelessWidget {
  const _LiveStatus({
    required this.state,
    required this.refreshEnabled,
    required this.onRefresh,
  });

  final TeacherBlitzMonitoringState state;
  final bool refreshEnabled;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final hasSnapshot = state.monitoring != null;
    final banner = !hasSnapshot
        ? null
        : state.pollingPausedByRateLimit
        ? (
            const Key('teacherBlitzMonitoringRateLimitBanner'),
            'Live updates are paused because too many requests were sent.',
          )
        : state.isStale
        ? (
            const Key('teacherBlitzMonitoringStaleBanner'),
            'Live monitoring may be out of date.',
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              state.livePollingEnabled
                  ? 'Live · updates every 5 seconds'
                  : 'Live updates paused',
              key: const Key('teacherBlitzMonitoringLiveStatus'),
            ),
            OutlinedButton.icon(
              key: const Key('teacherBlitzMonitoringRefreshButton'),
              onPressed: refreshEnabled ? onRefresh : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        if (state.isLoading && hasSnapshot && !state.lastRefreshWasAutomatic)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
              key: Key('teacherBlitzMonitoringRefreshing'),
              semanticsLabel: 'Refreshing Blitz monitoring',
            ),
          ),
        if (banner case (final key, final message)) ...[
          const SizedBox(height: 12),
          Card(
            key: key,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_outlined),
                  Semantics(liveRegion: true, child: Text(message)),
                  TextButton.icon(
                    key: const Key('teacherBlitzMonitoringRetryButton'),
                    onPressed: refreshEnabled ? onRefresh : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GrantBanner extends StatelessWidget {
  const _GrantBanner({required this.grant, required this.controller});

  final TeacherBlitzAttemptExceptionState grant;
  final TeacherBlitzAttemptExceptionController controller;

  @override
  Widget build(BuildContext context) {
    final uncertain =
        grant.status == TeacherBlitzAttemptExceptionStatus.uncertain;
    final settled =
        grant.status == TeacherBlitzAttemptExceptionStatus.confirmed ||
        grant.status == TeacherBlitzAttemptExceptionStatus.failure;

    return Card(
      key: const Key('teacherBlitzGrantBanner'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (grant.isBusy)
              const LinearProgressIndicator(
                key: Key('teacherBlitzGrantProgress'),
                semanticsLabel: 'Granting additional attempt',
              ),
            if (grant.message case final message?)
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  key: const Key('teacherBlitzGrantMessage'),
                ),
              ),
            if (uncertain || settled)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (uncertain && grant.canRetry)
                    FilledButton.icon(
                      key: const Key('teacherBlitzGrantRetryButton'),
                      onPressed: controller.retryGrant,
                      icon: const Icon(Icons.replay),
                      label: const Text('Retry grant'),
                    ),
                  if (uncertain && grant.canCheckMonitoring)
                    OutlinedButton.icon(
                      key: const Key('teacherBlitzGrantCheckMonitoringButton'),
                      onPressed: controller.checkMonitoring,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Check monitoring'),
                    ),
                  if (settled)
                    TextButton(
                      key: const Key('teacherBlitzGrantDismissButton'),
                      onPressed: controller.dismiss,
                      child: const Text('Dismiss'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MonitoringPlaceholder extends StatelessWidget {
  const _MonitoringPlaceholder({required this.state, required this.onRetry});

  final TeacherBlitzMonitoringState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.status != TeacherBlitzMonitoringStatus.error) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(
            key: Key('teacherBlitzMonitoringLoading'),
            semanticsLabel: 'Loading Blitz monitoring',
          ),
        ),
      );
    }
    return Card(
      key: const Key('teacherBlitzMonitoringError'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.pollingPausedByRateLimit
                  ? 'Live updates are paused because too many requests were '
                        'sent.'
                  : 'Blitz monitoring could not be loaded.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('teacherBlitzMonitoringRetryButton'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndedNotice extends StatelessWidget {
  const _EndedNotice({required this.status, required this.onBack});

  final TeacherBlitzMonitoringStatus status;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      TeacherBlitzMonitoringStatus.notActive => 'This Blitz is not active.',
      TeacherBlitzMonitoringStatus.closed => 'This Blitz has been closed.',
      TeacherBlitzMonitoringStatus.archived => 'This Blitz is archived.',
      _ => 'This Blitz is not available in your current Teacher workspace.',
    };
    return Card(
      key: const Key('teacherBlitzMonitoringEnded'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(liveRegion: true, child: Text(message)),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('teacherBlitzMonitoringEndedBackButton'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Blitz'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimingCard extends StatelessWidget {
  const _TimingCard({required this.monitoring, required this.timezone});

  final TeacherBlitzMonitoring monitoring;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final blitz = monitoring.blitz;
    final timing = blitz.timing;
    return Card(
      key: const Key('teacherBlitzMonitoringTiming'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _LabeledValue(
              label: 'Timer mode',
              value: teacherBlitzTimerModeLabel(timing.mode),
            ),
            _LabeledValue(
              label: 'Duration',
              value: formatTeacherBlitzDuration(blitz.durationSeconds),
            ),
            _LabeledValue(
              label: 'Activated at',
              value: _instant(blitz.activatedAt, timezone),
            ),
            _LabeledValue(
              label: 'Server snapshot',
              value: _instant(timing.serverNow, timezone),
            ),
            if (timing.synchronizedEndsAt case final endsAt?)
              _LabeledValue(
                label: 'Common end',
                value: _instant(endsAt, timezone),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final TeacherBlitzMonitoringSummary summary;

  @override
  Widget build(BuildContext context) {
    final counts = [
      ('Assigned', summary.assigned),
      ('Not started', summary.notStarted),
      ('In progress', summary.inProgress),
      ('Finalized', summary.finalized),
      ('Waiting for Teacher review', summary.waitingForTeacherReview),
      ('Additional attempts granted', summary.attemptExceptionsGranted),
    ];
    return Card(
      key: const Key('teacherBlitzMonitoringSummary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            for (final (label, count) in counts)
              MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count',
                      key: ValueKey(
                        'teacherBlitzMonitoringSummaryCount:$label',
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(label),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopStudentRow extends StatelessWidget {
  const _DesktopStudentRow({
    required this.row,
    required this.timezone,
    required this.onGrant,
  });

  final TeacherBlitzMonitoringStudent row;
  final String timezone;

  /// Null unless this row is a local grant candidate.
  final VoidCallback? onGrant;

  @override
  Widget build(BuildContext context) {
    final exception = row.attemptException;
    final reason = row.finalizationReason;
    return Card(
      key: ValueKey('teacherBlitzMonitoringStudent:${row.student.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  row.student.fullName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Chip(
                  label: Text(teacherBlitzMonitoringStatusLabel(row.status)),
                ),
                if (onGrant case final onGrant?)
                  OutlinedButton.icon(
                    key: ValueKey('teacherBlitzGrantButton:${row.student.id}'),
                    onPressed: onGrant,
                    icon: const Icon(Icons.add_task),
                    label: const Text('Grant additional attempt'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _LabeledValue(
                  label: 'Attempt',
                  value: teacherBlitzAttemptNumberLabel(row.attemptNumber),
                ),
                _LabeledValue(
                  label: 'Started',
                  value: _optionalInstant(row.startedAt, timezone),
                ),
                _LabeledValue(
                  label: 'Deadline',
                  value: _optionalInstant(row.deadlineAt, timezone),
                ),
                _LabeledValue(
                  label: 'Remaining',
                  value: formatTeacherBlitzRemaining(row.remainingSeconds),
                ),
                _LabeledValue(
                  label: 'Finalization',
                  value: reason == null
                      ? '—'
                      : teacherBlitzFinalizationReasonLabel(reason),
                ),
              ],
            ),
            if (exception != null) ...[
              const SizedBox(height: 12),
              Text(
                'Additional attempt granted',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _LabeledValue(
                    label: 'Reason type',
                    value: teacherBlitzAttemptExceptionReasonTypeLabel(
                      exception.reasonType,
                    ),
                  ),
                  _LabeledValue(
                    label: 'Granted at',
                    value: _instant(exception.grantedAt, timezone),
                  ),
                  _LabeledValue(
                    label: 'Replacement',
                    value: exception.replacementAttemptId == null
                        ? 'Waiting for Student to start additional attempt'
                        : 'Additional attempt already started',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _LabeledValue(label: 'Reason', value: exception.reason),
            ],
          ],
        ),
      ),
    );
  }
}

/// Basic mobile card: no reason text, identifiers or grant control.
class _MobileStudentCard extends StatelessWidget {
  const _MobileStudentCard({required this.row});

  final TeacherBlitzMonitoringStudent row;

  @override
  Widget build(BuildContext context) {
    final attemptNumber = row.attemptNumber;
    final remaining = row.remainingSeconds;
    final reason = row.finalizationReason;
    return Card(
      key: ValueKey('teacherBlitzMonitoringStudent:${row.student.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.student.fullName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(teacherBlitzMonitoringStatusLabel(row.status)),
                ),
                if (attemptNumber != null)
                  Text(teacherBlitzAttemptNumberLabel(attemptNumber)),
                if (row.attemptException != null)
                  const Chip(
                    avatar: Icon(Icons.add_task, size: 18),
                    label: Text('Additional attempt granted'),
                  ),
              ],
            ),
            if (remaining != null) ...[
              const SizedBox(height: 6),
              _LabeledValue(
                label: 'Remaining',
                value: formatTeacherBlitzRemaining(remaining),
              ),
            ],
            if (reason != null) ...[
              const SizedBox(height: 6),
              Text(teacherBlitzFinalizationReasonLabel(reason)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value, key: ValueKey('teacherBlitzMonitoringValue:$label')),
        ],
      ),
    );
  }
}

class _MonitoringUnavailable extends StatelessWidget {
  const _MonitoringUnavailable({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Blitz unavailable',
              key: const Key('teacherBlitzMonitoringUnavailable'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'This Blitz is not available in your current Teacher workspace.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onBack, child: const Text('Back to Blitz')),
          ],
        ),
      ),
    );
  }
}

class _ParentVerificationError extends StatelessWidget {
  const _ParentVerificationError({required this.onRetry, required this.onBack});

  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Unable to verify this Blitz',
              key: const Key('teacherBlitzMonitoringParentError'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Live monitoring starts after the Blitz is loaded again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton(
                  onPressed: onBack,
                  child: const Text('Back to Blitz'),
                ),
                FilledButton.icon(
                  key: const Key('teacherBlitzMonitoringParentRetryButton'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _instant(DateTime value, String timezone) {
  return formatInstitutionInstant(value, timezone) ?? formatUtcInstant(value);
}

String _optionalInstant(DateTime? value, String timezone) {
  return value == null ? '—' : _instant(value, timezone);
}
