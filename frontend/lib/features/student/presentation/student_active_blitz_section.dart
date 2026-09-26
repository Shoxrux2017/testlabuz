import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../application/student_active_blitz_controller.dart';
import '../application/student_active_blitz_state.dart';
import '../domain/student_blitz.dart';
import 'student_blitz_formatters.dart';

/// The Student's global active Blitz queue, independent of My Topics.
///
/// Cards show server-snapshot timing only; opening a card never starts an
/// Attempt.
class StudentActiveBlitzSection extends ConsumerWidget {
  const StudentActiveBlitzSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studentActiveBlitzControllerProvider);
    final controller = ref.read(studentActiveBlitzControllerProvider.notifier);
    final items = state.items;
    return Card(
      key: const Key('studentActiveBlitzSection'),
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
                      'Active Blitz',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('studentActiveBlitzRefreshButton'),
                  tooltip: 'Refresh active Blitz tasks',
                  onPressed: state.isRequestInFlight
                      ? null
                      : controller.refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items == null)
              switch (state.status) {
                StudentActiveBlitzStatus.error => _InitialError(
                  message: studentActiveBlitzFailureMessage(state.failure!),
                  onRetry: controller.retry,
                ),
                _ => const _Loading(),
              }
            else ...[
              if (state.status == StudentActiveBlitzStatus.refreshing) ...[
                const LinearProgressIndicator(
                  semanticsLabel: 'Refreshing active Blitz tasks',
                ),
                const SizedBox(height: 8),
              ],
              if (state.status == StudentActiveBlitzStatus.error &&
                  state.isStale) ...[
                _StaleNotice(onRetry: controller.retry),
                const SizedBox(height: 8),
              ],
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No active Blitz tasks are available right now.',
                    key: Key('studentActiveBlitzEmpty'),
                  ),
                )
              else
                for (final blitz in items) ...[
                  _ActiveBlitzCard(blitz: blitz),
                  const SizedBox(height: 8),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveBlitzCard extends StatelessWidget {
  const _ActiveBlitzCard({required this.blitz});

  final StudentActiveBlitzSummary blitz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timing = studentBlitzListTimingText(blitz);
    return Card(
      key: ValueKey('studentActiveBlitzCard${blitz.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(blitz.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text('Topic: ${blitz.topic.title}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(studentBlitzTimerModeLabel(blitz.timing.mode)),
                ),
                Chip(
                  label: Text(
                    'Duration: '
                    '${formatStudentBlitzDuration(blitz.durationSeconds)}',
                  ),
                ),
                Chip(label: Text(studentBlitzAttemptPathLabel(blitz.attempts))),
              ],
            ),
            if (timing != null) ...[const SizedBox(height: 8), Text(timing)],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                button: true,
                label: 'Open Blitz ${blitz.title}',
                excludeSemantics: true,
                child: FilledButton.tonalIcon(
                  key: ValueKey('studentActiveBlitzOpen${blitz.id}'),
                  onPressed: () => context.go(
                    AppRoutePaths.studentBlitzDetailLocation(
                      blitz.topic.id,
                      blitz.id,
                    ),
                  ),
                  icon: const Icon(Icons.bolt),
                  label: const Text('Open Blitz'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Loading active Blitz tasks',
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loading active Blitz tasks',
              key: Key('studentActiveBlitzLoading'),
            ),
          ),
        ],
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
      key: const Key('studentActiveBlitzError'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Active Blitz tasks could not be loaded.'),
        const SizedBox(height: 4),
        Text(message),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('studentActiveBlitzRetryButton'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

class _StaleNotice extends StatelessWidget {
  const _StaleNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('studentActiveBlitzStale'),
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(Icons.warning_amber),
        const Text('The active Blitz list may be out of date.'),
        TextButton(
          key: const Key('studentActiveBlitzStaleRetryButton'),
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
