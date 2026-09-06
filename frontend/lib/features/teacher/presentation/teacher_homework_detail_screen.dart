import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_failure.dart';
import '../application/teacher_homework_detail_controller.dart';
import '../application/teacher_homework_detail_state.dart';
import '../application/teacher_homework_route_target.dart';
import '../domain/teacher_homework.dart';
import 'teacher_homework_formatters.dart';
import 'teacher_question_read_view.dart';
import 'teacher_topic_formatters.dart';

class TeacherHomeworkDetailScreen extends ConsumerWidget {
  const TeacherHomeworkDetailScreen({
    required this.topicId,
    required this.homeworkId,
    super.key,
  });

  final String topicId;
  final String homeworkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = TeacherHomeworkRouteTarget(
      topicId: topicId,
      homeworkId: homeworkId,
    );
    final detailProvider = teacherHomeworkDetailControllerProvider(target);
    final detail = ref.watch(detailProvider);
    final surface = ref.watch(appDeviceSurfaceProvider);

    void backToTopic() {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
    }

    final hasConfirmedHomework = detail.homework != null;
    final homework = detail.status == TeacherHomeworkDetailStatus.data
        ? detail.homework
        : null;
    final canEdit =
        surface == AppDeviceSurface.desktop &&
        homework != null &&
        (homework.status == TeacherHomeworkStatus.draft ||
            homework.status == TeacherHomeworkStatus.active);

    return Scaffold(
      key: const Key('teacherHomeworkDetailScreen'),
      appBar: AppBar(
        title: const Text('Homework Detail'),
        leading: IconButton(
          key: const Key('teacherHomeworkBackButton'),
          tooltip: 'Back to Topic',
          onPressed: backToTopic,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (canEdit)
            TextButton.icon(
              key: const Key('teacherHomeworkManageQuestionsButton'),
              onPressed: () => context.go(
                AppRoutePaths.teacherHomeworkQuestionsLocation(
                  topicId,
                  homeworkId,
                ),
              ),
              icon: const Icon(Icons.quiz_outlined),
              label: const Text('Manage Questions'),
            ),
          if (canEdit)
            TextButton.icon(
              key: const Key('teacherHomeworkEditButton'),
              onPressed: () => context.go(
                AppRoutePaths.teacherHomeworkEditLocation(topicId, homeworkId),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          if (hasConfirmedHomework)
            IconButton(
              key: const Key('teacherHomeworkDetailRefreshButton'),
              tooltip: 'Refresh Homework',
              onPressed: detail.status == TeacherHomeworkDetailStatus.refreshing
                  ? null
                  : detail.status == TeacherHomeworkDetailStatus.error
                  ? ref.read(detailProvider.notifier).retry
                  : ref.read(detailProvider.notifier).refresh,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (detail.status) {
          TeacherHomeworkDetailStatus.initial ||
          TeacherHomeworkDetailStatus.loading => const Center(
            child: CircularProgressIndicator(
              key: Key('teacherHomeworkDetailLoading'),
              semanticsLabel: 'Loading Homework detail',
            ),
          ),
          TeacherHomeworkDetailStatus.notFound => _HomeworkUnavailable(
            onBack: backToTopic,
          ),
          TeacherHomeworkDetailStatus.error =>
            detail.homework == null
                ? _HomeworkDetailError(
                    failure: detail.failure,
                    onRetry: ref.read(detailProvider.notifier).retry,
                    onBack: backToTopic,
                  )
                : _HomeworkDetailContent(
                    homework: detail.homework!,
                    refreshing: false,
                    stale: detail.isStale,
                    onRetry: ref.read(detailProvider.notifier).retry,
                  ),
          TeacherHomeworkDetailStatus.data ||
          TeacherHomeworkDetailStatus.refreshing =>
            detail.homework == null
                ? _HomeworkDetailError(
                    failure: detail.failure,
                    onRetry: ref.read(detailProvider.notifier).retry,
                    onBack: backToTopic,
                  )
                : _HomeworkDetailContent(
                    homework: detail.homework!,
                    refreshing:
                        detail.status == TeacherHomeworkDetailStatus.refreshing,
                    stale: detail.isStale,
                    onRetry: ref.read(detailProvider.notifier).retry,
                  ),
        },
      ),
    );
  }
}

class _HomeworkDetailContent extends StatelessWidget {
  const _HomeworkDetailContent({
    required this.homework,
    required this.refreshing,
    required this.stale,
    required this.onRetry,
  });

  final TeacherHomework homework;
  final bool refreshing;
  final bool stale;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final assignment = switch (homework.assignmentMode) {
      TeacherHomeworkAssignmentMode.group => 'Whole group',
      TeacherHomeworkAssignmentMode.selectedStudents =>
        'Selected students: ${homework.studentIds.length}',
    };

    return SingleChildScrollView(
      key: const Key('teacherHomeworkDetailScroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (refreshing) ...[
                const LinearProgressIndicator(
                  key: Key('teacherHomeworkDetailProgress'),
                  semanticsLabel: 'Refreshing Homework detail',
                ),
                const SizedBox(height: 16),
              ],
              if (stale) ...[
                MaterialBanner(
                  key: const Key('teacherHomeworkDetailStaleMessage'),
                  content: const Text(
                    'The displayed Homework may be out of date.',
                  ),
                  actions: [
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ),
                const SizedBox(height: 12),
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
                          homework.title,
                          key: const Key('teacherHomeworkDetailTitle'),
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
                              teacherHomeworkStatusLabel(homework.status),
                            ),
                          ),
                          Chip(
                            label: Text(
                              teacherHomeworkAssignmentLabel(
                                homework.assignmentMode,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _HomeworkDetailCard(
                title: 'Summary',
                rows: [
                  ('Status', teacherHomeworkStatusLabel(homework.status)),
                  (
                    'Assignment mode',
                    teacherHomeworkAssignmentLabel(homework.assignmentMode),
                  ),
                  ('Question count', homework.questions.length.toString()),
                  (
                    'Total points',
                    formatTeacherHomeworkPoints(homework.totalPossiblePoints),
                  ),
                  (
                    'Deadline',
                    formatTeacherHomeworkDeadline(
                      homework.deadlineAt,
                      homework.institutionTimezone,
                    ),
                  ),
                  ('Institution timezone', homework.institutionTimezone),
                ],
              ),
              const SizedBox(height: 12),
              _HomeworkDetailCard(
                title: 'Instructions',
                rows: [
                  if (homework.description != null)
                    ('Description', homework.description!),
                  ('Student instructions', homework.studentInstructions),
                ],
              ),
              const SizedBox(height: 12),
              _HomeworkDetailCard(
                title: 'Assignment',
                rows: [('Recipients', assignment)],
              ),
              const SizedBox(height: 12),
              _HomeworkDetailCard(
                title: 'Attempt policy',
                rows: [
                  (
                    'Normal attempts',
                    homework.attemptPolicy.normalAttempts.toString(),
                  ),
                  (
                    'Official score',
                    teacherHomeworkOfficialScorePolicyLabel(
                      homework.attemptPolicy.officialScorePolicy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _HomeworkDetailCard(
                title: 'History',
                rows: [
                  ('Created', formatUtcInstant(homework.createdAt)),
                  ('Updated', formatUtcInstant(homework.updatedAt)),
                  if (homework.activatedAt != null)
                    ('Activated', formatUtcInstant(homework.activatedAt!)),
                  if (homework.closedAt != null)
                    ('Closed', formatUtcInstant(homework.closedAt!)),
                  if (homework.archivedAt != null)
                    ('Archived', formatUtcInstant(homework.archivedAt!)),
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
              for (final question in homework.questions) ...[
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

class _HomeworkDetailCard extends StatelessWidget {
  const _HomeworkDetailCard({required this.title, required this.rows});

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

class _HomeworkUnavailable extends StatelessWidget {
  const _HomeworkUnavailable({required this.onBack});

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
              'Homework unavailable',
              key: const Key('teacherHomeworkUnavailable'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'This Homework is not available in your current Teacher workspace.',
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

class _HomeworkDetailError extends StatelessWidget {
  const _HomeworkDetailError({
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
      ApiFailureKind.timeout => 'The Homework request timed out.',
      _ => 'The Homework could not be loaded.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Unable to load Homework',
              key: const Key('teacherHomeworkDetailError'),
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
                  key: const Key('teacherHomeworkDetailRetryButton'),
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
