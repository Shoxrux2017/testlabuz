import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/student_homework_list_controller.dart';
import '../application/student_homework_list_state.dart';
import '../domain/student_homework.dart';
import 'student_homework_formatters.dart';
import 'student_topic_formatters.dart';

class StudentHomeworkSection extends ConsumerWidget {
  const StudentHomeworkSection({required this.topicId, super.key});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = studentHomeworkListControllerProvider(
      topicId.toLowerCase(),
    );
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final timezone = ref
        .watch(authSessionControllerProvider)
        .user
        ?.institution
        ?.timezone;
    final page = state.page;
    final loading =
        state.status == StudentHomeworkListStatus.initial ||
        state.status == StudentHomeworkListStatus.loading;
    return Card(
      key: const Key('studentHomeworkSection'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              header: true,
              child: Text(
                'Homework',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 210,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Status filter',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<StudentHomeworkStatus?>(
                        key: const Key('studentHomeworkStatusFilter'),
                        value: state.query.status,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<StudentHomeworkStatus?>(
                            value: null,
                            child: Text('All'),
                          ),
                          for (final status in StudentHomeworkStatus.values)
                            DropdownMenuItem<StudentHomeworkStatus?>(
                              value: status,
                              child: Text(studentHomeworkStatusLabel(status)),
                            ),
                        ],
                        onChanged: state.isRequestInFlight
                            ? null
                            : controller.setStatus,
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Refresh Homework',
                  child: OutlinedButton.icon(
                    key: const Key('studentHomeworkRefreshButton'),
                    onPressed: state.isRequestInFlight
                        ? null
                        : controller.refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                key: Key('studentHomeworkLoading'),
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      semanticsLabel: 'Loading Homework',
                    ),
                    SizedBox(height: 12),
                    Text('Loading Homework'),
                  ],
                ),
              )
            else ...[
              if (state.status == StudentHomeworkListStatus.refreshing) ...[
                const LinearProgressIndicator(
                  key: Key('studentHomeworkRefreshing'),
                  semanticsLabel: 'Refreshing Homework',
                ),
                const SizedBox(height: 8),
                const Text('Refreshing Homework'),
                const SizedBox(height: 12),
              ],
              if (state.isStale) ...[
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Homework may be out of date. Refresh to see current information.',
                    key: Key('studentHomeworkStale'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (state.failure case final failure?) ...[
                Text(
                  'Unable to load Homework',
                  key: const Key('studentHomeworkListError'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(studentHomeworkFailureMessage(failure)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const Key('studentHomeworkRetryButton'),
                    onPressed: state.isRequestInFlight
                        ? null
                        : controller.retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (page != null) ...[
                if (page.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      page.total > 0
                          ? 'No Homework is available on this page.'
                          : state.query.status == null
                          ? 'No Homework is assigned for this Topic.'
                          : 'No Homework matches this status.',
                      key: const Key('studentHomeworkEmpty'),
                    ),
                  )
                else
                  for (final homework in page.items) ...[
                    _HomeworkSummaryCard(
                      homework: homework,
                      institutionTimezone: timezone ?? '',
                      canOpen:
                          !state.isStale &&
                          !state.isRequestInFlight &&
                          state.status == StudentHomeworkListStatus.data,
                    ),
                    const SizedBox(height: 10),
                  ],
                Wrap(
                  key: const Key('studentHomeworkPagination'),
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      key: const Key('studentHomeworkPreviousButton'),
                      onPressed: state.canGoPrevious
                          ? controller.previousPage
                          : null,
                      child: const Text('Previous'),
                    ),
                    Text('Page ${page.page} of ${page.lastPage}'),
                    OutlinedButton(
                      key: const Key('studentHomeworkNextButton'),
                      onPressed: state.canGoNext ? controller.nextPage : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeworkSummaryCard extends StatelessWidget {
  const _HomeworkSummaryCard({
    required this.homework,
    required this.institutionTimezone,
    required this.canOpen,
  });

  final StudentHomeworkSummary homework;
  final String institutionTimezone;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    final deadline = formatStudentInstitutionInstant(
      homework.deadlineAt,
      institutionTimezone,
    );
    return Card(
      key: ValueKey('studentHomeworkCard${homework.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              homework.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Homework: ${studentHomeworkStatusLabel(homework.status)}'),
            if (homework.deadlineAt != null)
              Text(
                'Deadline: ${deadline ?? 'Institution timezone unavailable'}',
              ),
            Text(
              'Attempts: ${homework.attempts.used} of ${homework.attempts.allowed} used',
            ),
            Text('Remaining: ${homework.attempts.remaining}'),
            Text('Status: ${studentHomeworkMyStatusLabel(homework.myStatus)}'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                button: true,
                label: 'Open Homework ${homework.title}',
                child: OutlinedButton(
                  key: ValueKey('studentHomeworkOpen${homework.id}'),
                  onPressed: canOpen
                      ? () => context.go(
                          AppRoutePaths.studentHomeworkDetailLocation(
                            homework.topic.id,
                            homework.id,
                          ),
                        )
                      : null,
                  child: const Text('Open Homework'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
