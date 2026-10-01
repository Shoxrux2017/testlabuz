import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/scoring/score_display.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/student_finished_blitz_controller.dart';
import '../application/student_finished_blitz_state.dart';
import '../domain/student_finished_blitz.dart';
import 'student_blitz_formatters.dart';
import 'student_topic_formatters.dart';

/// The Student's finished Blitz tasks with their released results
/// (`S09-D3`, `S09-D5`). A finished Blitz cannot be opened.
class StudentFinishedBlitzSection extends ConsumerWidget {
  const StudentFinishedBlitzSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studentFinishedBlitzControllerProvider);
    final controller = ref.read(
      studentFinishedBlitzControllerProvider.notifier,
    );
    final timezone =
        ref.watch(authSessionControllerProvider).user?.institution?.timezone ??
        '';
    final page = state.page;
    return Card(
      key: const Key('studentFinishedBlitzSection'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Finished Blitz',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('studentFinishedBlitzRefreshButton'),
                  tooltip: 'Refresh finished Blitz tasks',
                  onPressed: state.isRequestInFlight
                      ? null
                      : controller.refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (page == null)
              switch (state.status) {
                StudentFinishedBlitzLoadStatus.error => _InitialError(
                  message: studentFinishedBlitzFailureMessage(state.failure!),
                  onRetry: controller.retry,
                ),
                _ => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Loading finished Blitz tasks',
                    key: Key('studentFinishedBlitzLoading'),
                  ),
                ),
              }
            else ...[
              if (state.status ==
                  StudentFinishedBlitzLoadStatus.refreshing) ...[
                const LinearProgressIndicator(
                  key: Key('studentFinishedBlitzRefreshing'),
                  semanticsLabel: 'Refreshing finished Blitz tasks',
                ),
                const SizedBox(height: 8),
              ],
              if (state.status == StudentFinishedBlitzLoadStatus.error &&
                  state.isStale) ...[
                Wrap(
                  key: const Key('studentFinishedBlitzStale'),
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber),
                    const Text('The finished Blitz list may be out of date.'),
                    TextButton(
                      key: const Key('studentFinishedBlitzStaleRetryButton'),
                      onPressed: controller.retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (page.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No finished Blitz tasks yet.',
                    key: Key('studentFinishedBlitzEmpty'),
                  ),
                )
              else
                for (final blitz in page.items) ...[
                  _FinishedBlitzCard(blitz: blitz, timezone: timezone),
                  const SizedBox(height: 8),
                ],
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    key: const Key('studentFinishedBlitzPreviousButton'),
                    onPressed: state.canGoPrevious
                        ? controller.previousPage
                        : null,
                    child: const Text('Previous'),
                  ),
                  Text('Page ${page.page} of ${page.lastPage}'),
                  OutlinedButton(
                    key: const Key('studentFinishedBlitzNextButton'),
                    onPressed: state.canGoNext ? controller.nextPage : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FinishedBlitzCard extends StatelessWidget {
  const _FinishedBlitzCard({required this.blitz, required this.timezone});

  final StudentFinishedBlitz blitz;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final closed = formatStudentInstitutionInstant(blitz.closedAt, timezone);
    final result = blitz.result;
    final feedback = result?.feedback ?? const [];
    return Card(
      key: ValueKey('studentFinishedBlitzCard${blitz.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(blitz.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text('Topic: ${blitz.topic.title}'),
            Text('Closed ${closed ?? 'Institution timezone unavailable'}'),
            if (blitz.status == StudentFinishedBlitzStatus.archived) ...[
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Chip(label: Text('Archived')),
              ),
            ],
            if (blitz.attemptException) ...[
              const SizedBox(height: 4),
              const Text('Attempt 1 was invalidated.'),
            ],
            const SizedBox(height: 8),
            KeyedSubtree(
              key: ValueKey('studentFinishedBlitzResult${blitz.id}'),
              child: Text(switch (result) {
                StudentFinishedBlitzResult(:final normalizedScore?) =>
                  'Score ${formatScoreOneDecimal(normalizedScore)}',
                StudentFinishedBlitzResult() => 'Result not available yet',
                null when blitz.attemptException =>
                  'No replacement attempt was taken.',
                null => 'No attempt counts for this Blitz.',
              }, style: theme.textTheme.titleSmall),
            ),
            if (feedback.isNotEmpty) ...[
              const SizedBox(height: 8),
              Column(
                key: ValueKey('studentFinishedBlitzFeedback${blitz.id}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Teacher feedback', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  for (final entry in feedback)
                    SelectableText('Question ${entry.position}: ${entry.text}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InitialError extends StatelessWidget {
  const _InitialError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('studentFinishedBlitzError'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Finished Blitz tasks could not be loaded.'),
        const SizedBox(height: 4),
        Text(message),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('studentFinishedBlitzRetryButton'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
