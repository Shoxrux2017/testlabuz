import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_error_codes.dart';
import '../application/teacher_topic_result_list_controller.dart';
import '../application/teacher_topic_result_list_state.dart';
import '../domain/teacher_topic_result.dart';
import 'teacher_topic_result_formatters.dart';

/// The Topic results entry on the Topic detail page, on desktop and mobile
/// (`S10-FE-D1`): the cohort status counts and the way to the results list.
class TeacherTopicResultsCard extends ConsumerWidget {
  const TeacherTopicResultsCard({required this.topicId, super.key});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = teacherTopicResultListControllerProvider(
      topicId.toLowerCase(),
    );
    final state = ref.watch(provider);
    final counts = state.counts;
    final failure = state.status == TeacherTopicResultListStatus.error
        ? state.failure
        : null;
    // A Teacher who no longer teaches the Group gets 404; a retry cannot help.
    final unavailable =
        failure != null &&
        failure.statusCode == 404 &&
        failure.serverCode == ApiErrorCodes.resourceNotFound;
    final retry = failure == null || unavailable
        ? null
        : Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('teacherTopicResultsCardRetry'),
              onPressed: ref.read(provider.notifier).retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          );

    return Card(
      key: const Key('teacherTopicResultsCard'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Topic results',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 10),
            if (counts == null)
              if (failure != null) ...[
                Text(
                  unavailable
                      ? teacherTopicResultsFailureMessage(failure)
                      : 'Topic results could not be loaded.',
                ),
                if (retry != null) ...[const SizedBox(height: 8), retry],
              ] else
                const Align(
                  alignment: Alignment.centerLeft,
                  child: CircularProgressIndicator(
                    key: Key('teacherTopicResultsCardLoading'),
                    semanticsLabel: 'Loading Topic results',
                  ),
                )
            else ...[
              if (counts.total == 0)
                const Text(teacherTopicResultsEmptyMessage)
              else ...[
                Text('Students: ${counts.total}'),
                for (final status in TeacherTopicResultStatus.values)
                  if (counts.of(status) > 0)
                    Text(
                      '${teacherTopicResultStatusLabel(status)}: '
                      '${counts.of(status)}',
                      key: Key('teacherTopicResultsCount:${status.value}'),
                    ),
              ],
              // The counts were confirmed by an earlier load only.
              if (failure != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'These counts may be out of date.',
                  key: Key('teacherTopicResultsCardStale'),
                ),
                if (retry != null) ...[const SizedBox(height: 8), retry],
              ],
              if (counts.total > 0) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('teacherTopicResultsOpenButton'),
                    onPressed: () => context.push(
                      AppRoutePaths.teacherTopicResultsLocation(topicId),
                    ),
                    icon: const Icon(Icons.assessment_outlined),
                    label: const Text('Open results'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
