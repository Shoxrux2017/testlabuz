import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/student_homework_attempt_start_controller.dart';
import '../application/student_homework_attempt_start_state.dart';
import '../application/student_homework_detail_controller.dart';
import '../application/student_homework_detail_state.dart';
import '../domain/student_homework.dart';
import '../domain/student_homework_route_target.dart';
import 'student_homework_formatters.dart';
import 'student_question_read_view.dart';
import 'student_topic_formatters.dart';

class StudentHomeworkDetailScreen extends ConsumerWidget {
  const StudentHomeworkDetailScreen({required this.target, super.key});

  final StudentHomeworkRouteTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = studentHomeworkDetailControllerProvider(target);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final startProvider = studentHomeworkAttemptStartControllerProvider(target);
    final startState = ref.watch(startProvider);
    final startController = ref.read(startProvider.notifier);
    ref.listen(startProvider, (previous, next) {
      final attemptId = next.completedAttemptId;
      if (next.status != StudentHomeworkAttemptStartStatus.completed ||
          attemptId == null ||
          !isCanonicalStudentAttemptId(attemptId) ||
          !context.mounted) {
        return;
      }
      final router = GoRouter.maybeOf(context);
      final location = router?.routeInformationProvider.value.uri;
      // Consume even an offstage completion so it cannot navigate on return.
      if (!startController.consumeCompletion() ||
          ModalRoute.of(context)?.isCurrent != true ||
          location == null ||
          location.hasQuery ||
          location.hasFragment ||
          !AppRoutePaths.isStudentHomeworkDetailPath(location.path) ||
          AppRoutePaths.studentTopicIdFromPath(location.path)?.toLowerCase() !=
              target.topicId ||
          AppRoutePaths.studentHomeworkIdFromPath(
                location.path,
              )?.toLowerCase() !=
              target.homeworkId) {
        return;
      }
      context.go(
        AppRoutePaths.studentHomeworkAttemptLocation(
          target.topicId,
          target.homeworkId,
          attemptId,
        ),
      );
    });
    final timezone = ref
        .watch(authSessionControllerProvider)
        .user
        ?.institution
        ?.timezone;
    void backToTopic() =>
        context.go(AppRoutePaths.studentTopicDetailLocation(target.topicId));

    return Scaffold(
      key: const Key('studentHomeworkDetailScreen'),
      appBar: AppBar(
        title: const Text('Homework'),
        leading: IconButton(
          key: const Key('studentHomeworkBackButton'),
          tooltip: 'Back to Topic',
          onPressed: backToTopic,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (startState.status ==
                    StudentHomeworkAttemptStartStatus.uncertain ||
                startState.status ==
                    StudentHomeworkAttemptStartStatus.failure ||
                startState.status ==
                    StudentHomeworkAttemptStartStatus.submitting)
              _StartMutationStatus(
                state: startState,
                onRetry: startController.retry,
              ),
            Expanded(
              child: switch (state.status) {
                StudentHomeworkDetailStatus.initial ||
                StudentHomeworkDetailStatus.loading => const Center(
                  child: CircularProgressIndicator(
                    key: Key('studentHomeworkDetailLoading'),
                    semanticsLabel: 'Loading Homework detail',
                  ),
                ),
                StudentHomeworkDetailStatus.notFound => _HomeworkUnavailable(
                  onBack: backToTopic,
                ),
                StudentHomeworkDetailStatus.error => Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Unable to load Homework',
                          key: const Key('studentHomeworkDetailError'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          studentHomeworkFailureMessage(state.failure!),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            TextButton(
                              onPressed: backToTopic,
                              child: const Text('Back to Topic'),
                            ),
                            FilledButton.icon(
                              key: const Key(
                                'studentHomeworkDetailRetryButton',
                              ),
                              onPressed: controller.retry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                StudentHomeworkDetailStatus.data ||
                StudentHomeworkDetailStatus.refreshing =>
                  state.homework == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: 'Loading Homework detail',
                          ),
                        )
                      : _HomeworkDetailContent(
                          homework: state.homework!,
                          institutionTimezone: timezone ?? '',
                          refreshing:
                              state.status ==
                              StudentHomeworkDetailStatus.refreshing,
                          onRefresh: controller.refresh,
                          attemptAction: _attemptAction(
                            context,
                            state,
                            startState,
                            startController,
                          ),
                        ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget? _attemptAction(
    BuildContext context,
    StudentHomeworkDetailState detailState,
    StudentHomeworkAttemptStartState startState,
    StudentHomeworkAttemptStartController controller,
  ) {
    final homework = detailState.homework;
    if (detailState.status != StudentHomeworkDetailStatus.data ||
        homework == null ||
        startState.status == StudentHomeworkAttemptStartStatus.submitting ||
        startState.status == StudentHomeworkAttemptStartStatus.uncertain) {
      return null;
    }
    final inProgress = homework.attempts.inProgressAttempt;
    if (inProgress != null && isCanonicalStudentAttemptId(inProgress.id)) {
      final label = 'Resume Attempt ${inProgress.attemptNumber}';
      return FilledButton.icon(
        key: const Key('studentHomeworkResumeAttemptButton'),
        onPressed: () => context.go(
          AppRoutePaths.studentHomeworkAttemptLocation(
            target.topicId,
            target.homeworkId,
            inProgress.id,
          ),
        ),
        icon: const Icon(Icons.play_arrow),
        label: Text(label),
      );
    }
    if (homework.status != StudentHomeworkStatus.active ||
        homework.attempts.remaining <= 0 ||
        inProgress != null) {
      return null;
    }
    return FilledButton.icon(
      key: const Key('studentHomeworkStartAttemptButton'),
      onPressed: controller.start,
      icon: const Icon(Icons.play_arrow),
      label: const Text('Start Attempt'),
    );
  }
}

class _StartMutationStatus extends StatelessWidget {
  const _StartMutationStatus({required this.state, required this.onRetry});

  final StudentHomeworkAttemptStartState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.status == StudentHomeworkAttemptStartStatus.submitting)
            const FilledButton(
              key: Key('studentHomeworkStartAttemptButton'),
              onPressed: null,
              child: Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Starting Attempt, please wait',
                    ),
                  ),
                  Text('Starting Attempt…'),
                ],
              ),
            ),
          if (state.status == StudentHomeworkAttemptStartStatus.uncertain) ...[
            const Text(
              'We could not confirm whether the attempt started.\n'
              'Retry to safely check the same request.',
              key: Key('studentHomeworkStartUncertain'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('studentHomeworkRetryStartButton'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Start'),
            ),
          ],
          if (state.status == StudentHomeworkAttemptStartStatus.failure &&
              state.failure != null)
            Text(
              studentHomeworkStartFailureMessage(state.failure!),
              key: const Key('studentHomeworkStartFailure'),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    ),
  );
}

class _HomeworkDetailContent extends StatelessWidget {
  const _HomeworkDetailContent({
    required this.homework,
    required this.institutionTimezone,
    required this.refreshing,
    required this.onRefresh,
    required this.attemptAction,
  });

  final StudentHomeworkDetail homework;
  final String institutionTimezone;
  final bool refreshing;
  final VoidCallback onRefresh;
  final Widget? attemptAction;

  @override
  Widget build(BuildContext context) {
    final deadline = formatStudentInstitutionInstant(
      homework.deadlineAt,
      institutionTimezone,
    );
    final inProgress = homework.attempts.inProgressAttempt;
    final started = formatStudentInstitutionInstant(
      inProgress?.startedAt,
      institutionTimezone,
    );
    return SingleChildScrollView(
      key: const Key('studentHomeworkDetailScroll'),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (refreshing) ...[
                  const LinearProgressIndicator(
                    key: Key('studentHomeworkDetailRefreshing'),
                    semanticsLabel: 'Refreshing Homework detail',
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
                            homework.title,
                            key: const Key('studentHomeworkDetailTitle'),
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
                                studentHomeworkStatusLabel(homework.status),
                              ),
                            ),
                            Chip(
                              label: Text(
                                studentHomeworkMyStatusLabel(homework.myStatus),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Tooltip(
                            message: 'Refresh Homework detail',
                            child: OutlinedButton.icon(
                              key: const Key(
                                'studentHomeworkDetailRefreshButton',
                              ),
                              onPressed: refreshing ? null : onRefresh,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                          ),
                        ),
                        if (attemptAction != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: attemptAction!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _HomeworkInformationCard(
                  title: 'Homework information',
                  rows: [
                    ('Topic', homework.topic.title),
                    if (homework.description case final description?)
                      ('Description', description),
                    ('Student instructions', homework.studentInstructions),
                    if (homework.deadlineAt != null)
                      (
                        'Deadline',
                        deadline ?? 'Institution timezone unavailable',
                      ),
                    (
                      'Total possible points',
                      formatStudentHomeworkPoints(homework.totalPossiblePoints),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _HomeworkInformationCard(
                  title: 'Attempt information',
                  rows: [
                    ('Allowed attempts', '${homework.attempts.allowed}'),
                    ('Used', '${homework.attempts.used}'),
                    ('Remaining', '${homework.attempts.remaining}'),
                    (
                      'Official score policy',
                      'Highest valid completed attempt',
                    ),
                    if (inProgress != null)
                      (
                        'Attempt ${inProgress.attemptNumber} in progress',
                        'Started: ${started ?? 'Institution timezone unavailable'}',
                      ),
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
                const SizedBox(height: 12),
                if (homework.questions.isEmpty)
                  const Text(
                    'No Questions are available.',
                    key: Key('studentHomeworkQuestionsEmpty'),
                  )
                else
                  for (final question in homework.questions) ...[
                    StudentQuestionReadView(question: question),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeworkInformationCard extends StatelessWidget {
  const _HomeworkInformationCard({required this.title, required this.rows});

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

class _HomeworkUnavailable extends StatelessWidget {
  const _HomeworkUnavailable({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Homework unavailable',
              key: const Key('studentHomeworkUnavailable'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'This Homework is no longer available.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('studentHomeworkUnavailableBackButton'),
              onPressed: onBack,
              child: const Text('Back to Topic'),
            ),
          ],
        ),
      ),
    );
  }
}
