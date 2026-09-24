import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../application/teacher_blitz_list_controller.dart';
import '../application/teacher_blitz_list_state.dart';
import '../application/teacher_topic_detail_controller.dart';
import '../application/teacher_topic_detail_state.dart';
import '../application/teacher_topic_result_pair_controller.dart';
import '../domain/teacher_blitz.dart';
import '../domain/teacher_topic.dart';
import 'teacher_blitz_formatters.dart';
import 'teacher_homework_formatters.dart';
import 'teacher_workspace_list_widgets.dart';

/// Topic Blitz list with the desktop Create entry; lifecycle actions
/// belong to later tasks.
class TeacherBlitzSection extends ConsumerWidget {
  const TeacherBlitzSection({required this.topicId, super.key});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listProvider = teacherBlitzListControllerProvider(topicId);
    final state = ref.watch(listProvider);
    final controller = ref.read(listProvider.notifier);
    final pairState = ref.watch(
      teacherTopicResultPairControllerProvider(topicId),
    );
    // Official status needs confirmed pair data; absence is not proof of practice.
    final officialBlitzId = pairState.hasConfirmedData
        ? pairState.pair?.blitzAssessmentId
        : null;
    final topicDetail = ref.watch(
      teacherTopicDetailControllerProvider(topicId),
    );
    final topic = topicDetail.status == TeacherTopicDetailStatus.data
        ? topicDetail.topic
        : null;
    final canCreate =
        ref.watch(appDeviceSurfaceProvider) == AppDeviceSurface.desktop &&
        topic != null &&
        (topic.status == TeacherTopicStatus.draft ||
            topic.status == TeacherTopicStatus.active);

    return Card(
      key: const Key('teacherBlitzSection'),
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
                      'Blitz',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                if (canCreate) ...[
                  FilledButton.icon(
                    key: const Key('teacherBlitzCreateButton'),
                    onPressed: () => context.go(
                      AppRoutePaths.teacherBlitzCreateLocation(topicId),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Blitz'),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  key: const Key('teacherBlitzRefreshButton'),
                  tooltip: 'Refresh Blitz',
                  onPressed: state.isRequestInFlight
                      ? null
                      : controller.refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: constraints.maxWidth < 220
                      ? constraints.maxWidth
                      : 220,
                  child: _BlitzStatusFilter(
                    value: state.query.status,
                    onChanged: controller.setStatus,
                  ),
                ),
              ),
            ),
            if (state.status == TeacherBlitzListStatus.refreshing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                key: Key('teacherBlitzRefreshing'),
                semanticsLabel: 'Refreshing Blitz',
              ),
            ],
            if (state.isStale) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'The displayed Blitz list may be out of date.',
                    key: Key('teacherBlitzStaleMessage'),
                  ),
                  TextButton.icon(
                    key: const Key('teacherBlitzStaleRetryButton'),
                    onPressed: state.isRequestInFlight
                        ? null
                        : controller.retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _BlitzListBody(
              topicId: topicId,
              state: state,
              officialBlitzId: officialBlitzId,
              onRetry: controller.retry,
              onPrevious: controller.previousPage,
              onNext: controller.nextPage,
            ),
          ],
        ),
      ),
    );
  }
}

class _BlitzStatusFilter extends StatelessWidget {
  const _BlitzStatusFilter({required this.value, required this.onChanged});

  final TeacherBlitzStatus? value;
  final ValueChanged<TeacherBlitzStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      key: const Key('teacherBlitzStatusFilter'),
      decoration: const InputDecoration(labelText: 'Blitz status'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TeacherBlitzStatus?>(
          value: value,
          isExpanded: true,
          onChanged: onChanged,
          items: [
            const DropdownMenuItem<TeacherBlitzStatus?>(
              value: null,
              child: Text('All statuses'),
            ),
            for (final status in TeacherBlitzStatus.values)
              DropdownMenuItem<TeacherBlitzStatus?>(
                value: status,
                child: Text(teacherBlitzStatusLabel(status)),
              ),
          ],
        ),
      ),
    );
  }
}

class _BlitzListBody extends StatelessWidget {
  const _BlitzListBody({
    required this.topicId,
    required this.state,
    required this.officialBlitzId,
    required this.onRetry,
    required this.onPrevious,
    required this.onNext,
  });

  final String topicId;
  final TeacherBlitzListState state;
  final String? officialBlitzId;
  final VoidCallback onRetry;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    if (result == null) {
      if (state.status == TeacherBlitzListStatus.error) {
        return _BlitzListError(onRetry: onRetry);
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(
            key: Key('teacherBlitzLoading'),
            semanticsLabel: 'Loading Blitz',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              state.query.hasStatusFilter
                  ? 'No Blitz matches the current status filter.'
                  : 'No Blitz has been created for this Topic yet.',
              key: const Key('teacherBlitzEmpty'),
            ),
          )
        else
          for (var index = 0; index < result.items.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _BlitzCard(
              topicId: topicId,
              blitz: result.items[index],
              isOfficial:
                  officialBlitzId?.toLowerCase() ==
                  result.items[index].id.toLowerCase(),
            ),
          ],
        const SizedBox(height: 14),
        TeacherListPaginationControls(
          pagination: result.pagination,
          canPrevious: state.canGoPrevious,
          canNext: state.canGoNext,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
      ],
    );
  }
}

class _BlitzCard extends StatelessWidget {
  const _BlitzCard({
    required this.topicId,
    required this.blitz,
    required this.isOfficial,
  });

  final String topicId;
  final TeacherBlitzSummary blitz;
  final bool isOfficial;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open Blitz ${blitz.title}',
      child: Card.outlined(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('teacherBlitzCard${blitz.id}'),
          onTap: () => context.push(
            AppRoutePaths.teacherBlitzDetailLocation(topicId, blitz.id),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  blitz.title,
                  softWrap: true,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(teacherBlitzStatusLabel(blitz.status))),
                    Chip(
                      label: Text(
                        teacherBlitzAssignmentLabel(blitz.assignmentMode),
                      ),
                    ),
                    if (isOfficial)
                      Chip(
                        key: ValueKey('teacherBlitzOfficial${blitz.id}'),
                        label: const Text('Official'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Questions: ${blitz.questionCount}'),
                Text(
                  'Total points: '
                  '${formatTeacherHomeworkPoints(blitz.totalPossiblePoints)}',
                ),
                Text(
                  'Duration: ${formatTeacherBlitzDuration(blitz.durationSeconds)}',
                ),
                Text(
                  'Scheduled time: '
                  '${formatTeacherBlitzScheduledAt(blitz.scheduledAt, blitz.institutionTimezone)}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlitzListError extends StatelessWidget {
  const _BlitzListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Blitz could not be loaded.', key: Key('teacherBlitzError')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('teacherBlitzRetryButton'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
