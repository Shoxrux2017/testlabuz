import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_topic_detail_controller.dart';
import '../application/teacher_topic_detail_state.dart';
import '../application/teacher_topic_lifecycle_controller.dart';
import '../application/teacher_topic_lifecycle_state.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_mutation.dart';
import 'teacher_topic_formatters.dart';

class TeacherTopicDetailScreen extends ConsumerWidget {
  const TeacherTopicDetailScreen({required this.topicId, super.key});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailProvider = teacherTopicDetailControllerProvider(topicId);
    final detail = ref.watch(detailProvider);
    final surface = ref.watch(appDeviceSurfaceProvider);
    final timezone = ref.watch(
      authSessionControllerProvider.select(
        (session) => session.user?.institution?.timezone,
      ),
    );
    final lifecycleProvider = teacherTopicLifecycleControllerProvider(topicId);
    final lifecycle = surface == AppDeviceSurface.desktop
        ? ref.watch(lifecycleProvider)
        : const TeacherTopicLifecycleState();
    if (surface == AppDeviceSurface.desktop) {
      ref.listen<String?>(lifecycleProvider.select((state) => state.feedback), (
        _,
        feedback,
      ) {
        if (feedback == null || !context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(feedback)));
        ref.read(lifecycleProvider.notifier).consumeFeedback();
      });
    }

    return Scaffold(
      key: const Key('teacherTopicDetailScreen'),
      appBar: AppBar(
        title: const Text('Topic Detail'),
        leading: IconButton(
          key: const Key('teacherTopicBackButton'),
          tooltip: 'Back to Topics',
          onPressed: () => context.go(AppRoutePaths.teacher),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: switch (detail.status) {
          TeacherTopicDetailStatus.initial ||
          TeacherTopicDetailStatus.loading => const Center(
            child: CircularProgressIndicator(
              key: Key('teacherTopicDetailLoading'),
              semanticsLabel: 'Loading Topic detail',
            ),
          ),
          TeacherTopicDetailStatus.notFound => _UnavailableTopic(
            onBack: () => context.go(AppRoutePaths.teacher),
          ),
          TeacherTopicDetailStatus.error => _TopicDetailError(
            failure: detail.failure!,
            onRetry: ref.read(detailProvider.notifier).refresh,
            onBack: () => context.go(AppRoutePaths.teacher),
          ),
          TeacherTopicDetailStatus.data ||
          TeacherTopicDetailStatus.refreshing => _TopicDetailContent(
            topic: detail.topic!,
            institutionTimezone: timezone,
            surface: surface,
            refreshing: detail.status == TeacherTopicDetailStatus.refreshing,
            lifecycle: lifecycle,
            onRefresh: ref.read(detailProvider.notifier).refresh,
            onEdit: () => context.go(
              AppRoutePaths.teacherTopicEditLocation(detail.topic!.id),
            ),
            onLifecycle: (action) => _confirmLifecycle(
              context,
              action,
              () => ref.read(lifecycleProvider.notifier).perform(action),
            ),
            onCheckCurrent: ref
                .read(lifecycleProvider.notifier)
                .checkCurrentTopic,
          ),
        },
      ),
    );
  }
}

class _TopicDetailContent extends StatelessWidget {
  const _TopicDetailContent({
    required this.topic,
    required this.institutionTimezone,
    required this.surface,
    required this.refreshing,
    required this.lifecycle,
    required this.onRefresh,
    required this.onEdit,
    required this.onLifecycle,
    required this.onCheckCurrent,
  });

  final TeacherTopic topic;
  final String? institutionTimezone;
  final AppDeviceSurface surface;
  final bool refreshing;
  final TeacherTopicLifecycleState lifecycle;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final ValueChanged<TeacherTopicLifecycleAction> onLifecycle;
  final VoidCallback onCheckCurrent;

  @override
  Widget build(BuildContext context) {
    final timezone = institutionTimezone;
    final lessonAt = timezone == null
        ? null
        : formatInstitutionInstant(topic.lessonAt, timezone);
    final isDesktop = surface == AppDeviceSurface.desktop;
    final lifecycleActions = isDesktop
        ? teacherTopicLifecycleActions(topic)
        : const <TeacherTopicLifecycleAction>[];

    return SingleChildScrollView(
      key: const Key('teacherTopicDetailScroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (refreshing || lifecycle.isBusy) ...[
                LinearProgressIndicator(
                  key: const Key('teacherTopicDetailProgress'),
                  semanticsLabel: lifecycle.isBusy
                      ? 'Updating Topic'
                      : 'Refreshing Topic',
                ),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          topic.title,
                          key: const Key('teacherTopicDetailTitle'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              'Topic: ${teacherTopicStatusLabel(topic.status)}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Group: ${teacherGroupStatusLabel(topic.group.status)}',
                            ),
                          ),
                        ],
                      ),
                      if (isDesktop) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          key: const Key('teacherTopicDetailActions'),
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (teacherTopicCanEdit(topic))
                              OutlinedButton.icon(
                                key: const Key('teacherTopicEditButton'),
                                onPressed: lifecycle.isBusy ? null : onEdit,
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                              ),
                            for (final action in lifecycleActions)
                              FilledButton.tonalIcon(
                                key: ValueKey(
                                  'teacherTopicLifecycle${action.name}',
                                ),
                                onPressed: lifecycle.isBusy
                                    ? null
                                    : () => onLifecycle(action),
                                icon: Icon(_lifecycleIcon(action)),
                                label: Text(_lifecycleLabel(action)),
                              ),
                            OutlinedButton.icon(
                              key: const Key('teacherTopicDetailRefreshButton'),
                              onPressed: refreshing || lifecycle.isBusy
                                  ? null
                                  : onRefresh,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                            if (lifecycle.canCheckCurrent)
                              FilledButton(
                                key: const Key(
                                  'teacherTopicLifecycleCheckCurrentButton',
                                ),
                                onPressed: onCheckCurrent,
                                child: const Text('Check current Topic'),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _DetailCard(
                title: 'Topic information',
                rows: [
                  ('Subject', topic.subject),
                  if (topic.description != null)
                    ('Description', topic.description!),
                  ('Student instructions', topic.studentInstructions),
                  (
                    'Lesson time',
                    topic.lessonAt == null
                        ? 'Not scheduled'
                        : lessonAt ?? 'Institution timezone unavailable',
                  ),
                  if (timezone != null) ('Institution timezone', timezone),
                ],
              ),
              const SizedBox(height: 12),
              _DetailCard(
                title: 'Group',
                rows: [
                  ('Name', topic.group.name),
                  if (topic.group.level != null) ('Level', topic.group.level!),
                  if (topic.group.subjectDirection != null)
                    ('Subject direction', topic.group.subjectDirection!),
                  ('Status', teacherGroupStatusLabel(topic.group.status)),
                ],
              ),
              const SizedBox(height: 12),
              _DetailCard(
                title: 'History',
                rows: [
                  ('Created', formatUtcInstant(topic.createdAt)),
                  ('Updated', formatUtcInstant(topic.updatedAt)),
                  if (topic.activatedAt != null)
                    ('Activated', formatUtcInstant(topic.activatedAt!)),
                  if (topic.closedAt != null)
                    ('Closed', formatUtcInstant(topic.closedAt!)),
                  if (topic.archivedAt != null)
                    ('Archived', formatUtcInstant(topic.archivedAt!)),
                ],
              ),
              if (isDesktop) ...[
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Learning Materials are required before Topic activation.',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.rows});

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
            Text(title, style: Theme.of(context).textTheme.titleMedium),
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

class _UnavailableTopic extends StatelessWidget {
  const _UnavailableTopic({required this.onBack});

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
              'Topic unavailable',
              key: const Key('teacherTopicUnavailable'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'This Topic is not available in your current Teacher workspace.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onBack,
              child: const Text('Back to Topics'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicDetailError extends StatelessWidget {
  const _TopicDetailError({
    required this.failure,
    required this.onRetry,
    required this.onBack,
  });

  final ApiFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The Topic request timed out.',
      _ => 'The Topic could not be loaded.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Unable to load Topic',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton(onPressed: onBack, child: const Text('Back')),
                FilledButton.icon(
                  key: const Key('teacherTopicDetailRetryButton'),
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

Future<void> _confirmLifecycle(
  BuildContext context,
  TeacherTopicLifecycleAction action,
  VoidCallback confirm,
) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(_lifecycleDialogTitle(action)),
      content: Text(_lifecycleExplanation(action)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('teacherTopicLifecycleConfirmButton'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(_lifecycleLabel(action)),
        ),
      ],
    ),
  );
  if (accepted == true && context.mounted) {
    confirm();
  }
}

String _lifecycleLabel(TeacherTopicLifecycleAction action) => switch (action) {
  TeacherTopicLifecycleAction.activate => 'Activate',
  TeacherTopicLifecycleAction.close => 'Close',
  TeacherTopicLifecycleAction.archive => 'Archive',
};

String _lifecycleDialogTitle(TeacherTopicLifecycleAction action) =>
    switch (action) {
      TeacherTopicLifecycleAction.activate => 'Activate Topic?',
      TeacherTopicLifecycleAction.close => 'Close Topic?',
      TeacherTopicLifecycleAction.archive => 'Archive Topic?',
    };

String _lifecycleExplanation(
  TeacherTopicLifecycleAction action,
) => switch (action) {
  TeacherTopicLifecycleAction.activate =>
    'The Topic becomes active learning content for authorized Students. Activation requires valid Topic information and at least one current Learning Material. The server makes the final readiness decision.',
  TeacherTopicLifecycleAction.close =>
    'The Topic leaves active use and metadata editing becomes unavailable according to server lifecycle rules.',
  TeacherTopicLifecycleAction.archive =>
    'The Topic content is retained as historical read-only data.',
};

IconData _lifecycleIcon(TeacherTopicLifecycleAction action) => switch (action) {
  TeacherTopicLifecycleAction.activate => Icons.play_arrow,
  TeacherTopicLifecycleAction.close => Icons.stop_circle_outlined,
  TeacherTopicLifecycleAction.archive => Icons.archive_outlined,
};
