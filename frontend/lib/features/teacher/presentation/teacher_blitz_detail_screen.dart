import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_failure.dart';
import '../application/teacher_blitz_detail_controller.dart';
import '../application/teacher_blitz_detail_state.dart';
import '../application/teacher_blitz_lifecycle_controller.dart';
import '../application/teacher_blitz_lifecycle_state.dart';
import '../application/teacher_blitz_route_mutation_activity.dart';
import '../application/teacher_blitz_route_target.dart';
import '../application/teacher_official_blitz_controller.dart';
import '../application/teacher_official_blitz_state.dart';
import '../application/teacher_topic_result_pair_controller.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_blitz_form.dart';
import 'teacher_blitz_formatters.dart';
import 'teacher_blitz_lifecycle_controls.dart';
import 'teacher_homework_formatters.dart';
import 'teacher_question_read_view.dart';
import 'teacher_topic_formatters.dart';

/// Blitz detail with desktop authoring and lifecycle controls, mobile
/// Activate, and the monitoring entry for an Active Blitz.
class TeacherBlitzDetailScreen extends ConsumerStatefulWidget {
  const TeacherBlitzDetailScreen({required this.target, super.key});

  final TeacherBlitzRouteTarget target;

  @override
  ConsumerState<TeacherBlitzDetailScreen> createState() =>
      _TeacherBlitzDetailScreenState();
}

class _TeacherBlitzDetailScreenState
    extends ConsumerState<TeacherBlitzDetailScreen> {
  late TeacherBlitzRouteTarget _target;
  late TeacherBlitzLifecycleController _lifecycleController;
  late TeacherOfficialBlitzController _officialController;
  late TeacherBlitzRouteMutationActivityController _activityController;

  @override
  void initState() {
    super.initState();
    _bindTarget();
  }

  @override
  void didUpdateWidget(covariant TeacherBlitzDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target == widget.target) {
      return;
    }
    final oldLifecycle = _lifecycleController;
    final oldOfficial = _officialController;
    final oldActivity = _activityController;
    oldLifecycle.invalidateRouteCompletions();
    oldOfficial.invalidateRouteCompletions();
    _bindTarget();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldLifecycle.leaveRoute();
      oldOfficial.leaveRoute();
      oldActivity.endRoute();
    });
  }

  @override
  void dispose() {
    final lifecycle = _lifecycleController;
    final official = _officialController;
    final activity = _activityController;
    lifecycle.invalidateRouteCompletions();
    official.invalidateRouteCompletions();
    // Provider state may not change while the tree is finalizing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      lifecycle.leaveRoute();
      official.leaveRoute();
      activity.endRoute();
    });
    super.dispose();
  }

  void _bindTarget() {
    _target = widget.target;
    _lifecycleController = ref.read(
      teacherBlitzLifecycleControllerProvider(_target).notifier,
    );
    _officialController = ref.read(
      teacherOfficialBlitzControllerProvider(_target).notifier,
    );
    _activityController = ref.read(
      teacherBlitzRouteMutationActivityProvider(_target).notifier,
    );
  }

  bool _isCurrentTarget(TeacherBlitzRouteTarget target) {
    return mounted && _target == target;
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    final detailProvider = teacherBlitzDetailControllerProvider(target);
    final detail = ref.watch(detailProvider);
    final controller = ref.read(detailProvider.notifier);
    final pairState = ref.watch(
      teacherTopicResultPairControllerProvider(target.topicId.toLowerCase()),
    );
    final isDesktop =
        ref.watch(appDeviceSurfaceProvider) == AppDeviceSurface.desktop;
    final activity = ref.watch(
      teacherBlitzRouteMutationActivityProvider(target),
    );
    final lifecycle = ref.watch(
      teacherBlitzLifecycleControllerProvider(target),
    );
    final blitz = detail.blitz;
    final isOfficial =
        blitz != null &&
        pairState.hasConfirmedData &&
        pairState.pair?.blitzAssessmentId?.toLowerCase() ==
            blitz.id.toLowerCase();
    final hasCurrentDetail =
        detail.status == TeacherBlitzDetailStatus.data && !detail.isStale;

    _listenForFeedback(context, target);

    // Authoring needs a confirmed current Draft/Scheduled Blitz on desktop.
    final showAuthoring =
        isDesktop &&
        blitz != null &&
        hasCurrentDetail &&
        isTeacherBlitzAuthoringStatus(blitz.status);
    // Mobile shows lifecycle controls only for Activate and its outcome.
    final showLifecycleControls =
        blitz != null &&
        (isDesktop ||
            isTeacherBlitzAuthoringStatus(blitz.status) ||
            lifecycle.isBusy ||
            lifecycle.notice != null);
    final showMonitor =
        blitz != null &&
        hasCurrentDetail &&
        blitz.status == TeacherBlitzStatus.active;

    void editBlitz() {
      context.go(
        AppRoutePaths.teacherBlitzEditLocation(target.topicId, target.blitzId),
      );
    }

    void manageQuestions() {
      context.go(
        AppRoutePaths.teacherBlitzQuestionsLocation(
          target.topicId,
          target.blitzId,
        ),
      );
    }

    void monitor() {
      context.go(
        AppRoutePaths.teacherBlitzMonitoringLocation(
          target.topicId,
          target.blitzId,
        ),
      );
    }

    // The nested route normally pops to its Topic; `go` covers an empty stack.
    void backToTopic() {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go(AppRoutePaths.teacherTopicDetailLocation(target.topicId));
    }

    return Scaffold(
      key: const Key('teacherBlitzDetailScreen'),
      appBar: AppBar(
        title: const Text('Blitz Detail'),
        leading: IconButton(
          key: const Key('teacherBlitzBackButton'),
          tooltip: 'Back to Topic',
          onPressed: backToTopic,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (showAuthoring)
            TextButton.icon(
              key: const Key('teacherBlitzManageQuestionsButton'),
              onPressed: activity.isActive ? null : manageQuestions,
              icon: const Icon(Icons.quiz_outlined),
              label: const Text('Manage Questions'),
            ),
          if (showAuthoring)
            TextButton.icon(
              key: const Key('teacherBlitzEditButton'),
              onPressed: activity.isActive ? null : editBlitz,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          if (blitz != null)
            IconButton(
              key: const Key('teacherBlitzDetailRefreshButton'),
              tooltip: 'Refresh Blitz',
              onPressed: detail.isLoading || activity.isActive
                  ? null
                  : () {
                      // A refresh shows server truth; settled notices go.
                      _lifecycleController.clearNotice();
                      _officialController.clearNotice();
                      if (detail.status == TeacherBlitzDetailStatus.error) {
                        controller.retry();
                      } else {
                        controller.refresh();
                      }
                    },
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (detail.status) {
          TeacherBlitzDetailStatus.initial ||
          TeacherBlitzDetailStatus.loading => const Center(
            child: CircularProgressIndicator(
              key: Key('teacherBlitzDetailLoading'),
              semanticsLabel: 'Loading Blitz detail',
            ),
          ),
          TeacherBlitzDetailStatus.notFound => _BlitzUnavailable(
            onBack: backToTopic,
          ),
          TeacherBlitzDetailStatus.data ||
          TeacherBlitzDetailStatus.refreshing ||
          TeacherBlitzDetailStatus.error =>
            blitz == null
                ? _BlitzDetailError(
                    failure: detail.failure,
                    onRetry: controller.retry,
                    onBack: backToTopic,
                  )
                : _BlitzDetailContent(
                    blitz: blitz,
                    isOfficial: isOfficial,
                    refreshing:
                        detail.status == TeacherBlitzDetailStatus.refreshing,
                    stale: detail.isStale,
                    onRetry: controller.retry,
                    onMonitor: showMonitor ? monitor : null,
                    // A lifecycle result must not land on the monitoring route.
                    monitorEnabled: !activity.isActive,
                    lifecycleControls: showLifecycleControls
                        ? TeacherBlitzLifecycleControls(
                            target: target,
                            blitz: blitz,
                            mutationsAvailable: hasCurrentDetail,
                            isCurrentTarget: _isCurrentTarget,
                            onEditBlitz: editBlitz,
                            onManageQuestions: manageQuestions,
                          )
                        : null,
                  ),
        },
      ),
    );
  }

  void _listenForFeedback(
    BuildContext context,
    TeacherBlitzRouteTarget target,
  ) {
    final lifecycleProvider = teacherBlitzLifecycleControllerProvider(target);
    final officialProvider = teacherOfficialBlitzControllerProvider(target);
    ref.listen<TeacherBlitzLifecycleState>(lifecycleProvider, (_, next) {
      final feedback = next.feedback;
      if (feedback == null || !context.mounted) {
        return;
      }
      _showFeedback(context, feedback);
      ref.read(lifecycleProvider.notifier).consumeFeedback();
    });
    ref.listen<TeacherOfficialBlitzState>(officialProvider, (_, next) {
      final feedback = next.feedback;
      if (feedback == null || !context.mounted) {
        return;
      }
      _showFeedback(context, feedback);
      ref.read(officialProvider.notifier).consumeFeedback();
    });
  }

  void _showFeedback(BuildContext context, String feedback) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(feedback)));
  }
}

class _BlitzDetailContent extends StatelessWidget {
  const _BlitzDetailContent({
    required this.blitz,
    required this.isOfficial,
    required this.refreshing,
    required this.stale,
    required this.onRetry,
    required this.onMonitor,
    required this.monitorEnabled,
    required this.lifecycleControls,
  });

  final TeacherBlitz blitz;
  final bool isOfficial;
  final bool refreshing;
  final bool stale;
  final VoidCallback onRetry;

  /// Null unless the confirmed current Blitz is Active.
  final VoidCallback? onMonitor;
  final bool monitorEnabled;
  final Widget? lifecycleControls;

  @override
  Widget build(BuildContext context) {
    final activatedAt = blitz.activatedAt;
    final synchronizedEndsAt = blitz.synchronizedEndsAt;
    final closedAt = blitz.closedAt;
    final archivedAt = blitz.archivedAt;

    return SingleChildScrollView(
      key: const Key('teacherBlitzDetailScroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (refreshing) ...[
                const LinearProgressIndicator(
                  key: Key('teacherBlitzDetailProgress'),
                  semanticsLabel: 'Refreshing Blitz detail',
                ),
                const SizedBox(height: 16),
              ],
              if (stale) ...[
                MaterialBanner(
                  key: const Key('teacherBlitzDetailStaleMessage'),
                  content: const Text(
                    'The displayed Blitz may be out of date.',
                  ),
                  actions: [
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Card(
                key: const Key('teacherBlitzDetailHeader'),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          blitz.title,
                          key: const Key('teacherBlitzDetailTitle'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(teacherBlitzStatusLabel(blitz.status)),
                          ),
                          Chip(
                            label: Text(
                              teacherBlitzAssignmentLabel(blitz.assignmentMode),
                            ),
                          ),
                          if (isOfficial)
                            const Chip(
                              key: Key('teacherBlitzDetailOfficialChip'),
                              label: Text('Official'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (onMonitor case final onMonitor?) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('teacherBlitzMonitorButton'),
                    onPressed: monitorEnabled ? onMonitor : null,
                    icon: const Icon(Icons.monitor_heart_outlined),
                    label: const Text('Monitor'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (lifecycleControls case final controls?) ...[
                controls,
                const SizedBox(height: 12),
              ],
              _BlitzDetailCard(
                title: 'Blitz information',
                rows: [
                  if (blitz.description case final description?)
                    ('Description', description),
                  ('Student instructions', blitz.studentInstructions),
                  (
                    'Assignment',
                    teacherBlitzAssignmentLabel(blitz.assignmentMode),
                  ),
                  if (blitz.assignmentMode ==
                      TeacherBlitzAssignmentMode.selectedStudents)
                    ('Selected students', blitz.studentIds.length.toString()),
                  (
                    'Total possible points',
                    formatTeacherHomeworkPoints(blitz.totalPossiblePoints),
                  ),
                  ('Question count', blitz.questions.length.toString()),
                  ('Institution timezone', blitz.institutionTimezone),
                ],
              ),
              const SizedBox(height: 12),
              _BlitzDetailCard(
                title: 'Timing',
                rows: [
                  (
                    'Duration',
                    formatTeacherBlitzDuration(blitz.durationSeconds),
                  ),
                  (
                    'Scheduled time',
                    formatTeacherBlitzScheduledAt(
                      blitz.scheduledAt,
                      blitz.institutionTimezone,
                    ),
                  ),
                  (
                    'Timer start mode',
                    teacherBlitzTimerModeLabel(blitz.timerStartModeSnapshot),
                  ),
                  if (activatedAt != null)
                    ('Activated at', formatUtcInstant(activatedAt)),
                  if (synchronizedEndsAt != null)
                    (
                      'Synchronized common end',
                      formatUtcInstant(synchronizedEndsAt),
                    ),
                  if (closedAt != null)
                    ('Closed at', formatUtcInstant(closedAt)),
                  if (archivedAt != null)
                    ('Archived at', formatUtcInstant(archivedAt)),
                ],
              ),
              const SizedBox(height: 12),
              _BlitzDetailCard(
                title: 'Attempt policy',
                rows: [
                  (
                    'Normal attempts',
                    blitz.attemptPolicy.normalAttempts.toString(),
                  ),
                  (
                    'Maximum additional exception attempts',
                    blitz.attemptPolicy.maxAdditionalExceptionAttempts
                        .toString(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BlitzDetailCard(
                title: 'History',
                rows: [
                  ('Created', formatUtcInstant(blitz.createdAt)),
                  ('Updated', formatUtcInstant(blitz.updatedAt)),
                  if (activatedAt != null)
                    ('Activated', formatUtcInstant(activatedAt)),
                  if (closedAt != null) ('Closed', formatUtcInstant(closedAt)),
                  if (archivedAt != null)
                    ('Archived', formatUtcInstant(archivedAt)),
                ],
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  'Questions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              if (blitz.questions.isEmpty)
                const Text(
                  'No Questions have been added.',
                  key: Key('teacherBlitzNoQuestions'),
                )
              else
                for (final question in blitz.questions) ...[
                  TeacherQuestionReadView(question: question),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BlitzDetailCard extends StatelessWidget {
  const _BlitzDetailCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('teacherBlitzDetailCard:$title'),
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
            const SizedBox(height: 10),
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
  const _BlitzUnavailable({required this.onBack});

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
              key: const Key('teacherBlitzUnavailable'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'This Blitz is not available in your current Teacher workspace.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onBack, child: const Text('Back to Topic')),
          ],
        ),
      ),
    );
  }
}

class _BlitzDetailError extends StatelessWidget {
  const _BlitzDetailError({
    required this.failure,
    required this.onRetry,
    required this.onBack,
  });

  final ApiFailure? failure;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure?.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The Blitz request timed out.',
      _ => 'The Blitz could not be loaded.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Unable to load Blitz',
              key: const Key('teacherBlitzDetailError'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton(
                  onPressed: onBack,
                  child: const Text('Back to Topic'),
                ),
                FilledButton.icon(
                  key: const Key('teacherBlitzDetailRetryButton'),
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
