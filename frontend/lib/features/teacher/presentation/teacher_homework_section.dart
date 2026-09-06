import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../application/teacher_topic_detail_controller.dart';
import '../application/teacher_topic_detail_state.dart';
import '../application/teacher_homework_list_controller.dart';
import '../application/teacher_homework_list_state.dart';
import '../domain/teacher_homework.dart';
import '../domain/teacher_homework_list.dart';
import '../domain/teacher_homework_list_query.dart';
import '../domain/teacher_topic.dart';
import 'teacher_homework_formatters.dart';

class TeacherHomeworkSection extends ConsumerStatefulWidget {
  const TeacherHomeworkSection({required this.topicId, super.key});

  final String topicId;

  @override
  ConsumerState<TeacherHomeworkSection> createState() =>
      _TeacherHomeworkSectionState();
}

class _TeacherHomeworkSectionState
    extends ConsumerState<TeacherHomeworkSection> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listProvider = teacherHomeworkListControllerProvider(widget.topicId);
    final state = ref.watch(listProvider);
    final controller = ref.read(listProvider.notifier);
    final topicProvider = teacherTopicDetailControllerProvider(widget.topicId);
    final topicDetail = ref.watch(topicProvider);
    final topic = topicDetail.status == TeacherTopicDetailStatus.data
        ? topicDetail.topic
        : null;
    final canCreate =
        ref.watch(appDeviceSurfaceProvider) == AppDeviceSurface.desktop &&
        topic != null &&
        (topic.status == TeacherTopicStatus.draft ||
            topic.status == TeacherTopicStatus.active);

    if (_searchController.text != state.searchDraft) {
      _searchController.value = TextEditingValue(
        text: state.searchDraft,
        selection: TextSelection.collapsed(offset: state.searchDraft.length),
      );
    }

    return Card(
      key: const Key('teacherHomeworkSection'),
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
                      'Homework',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                if (canCreate) ...[
                  FilledButton.icon(
                    key: const Key('teacherHomeworkCreateButton'),
                    onPressed: () => context.go(
                      AppRoutePaths.teacherHomeworkCreateLocation(
                        widget.topicId,
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Homework'),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  key: const Key('teacherHomeworkRefreshButton'),
                  tooltip: 'Refresh Homework',
                  onPressed: state.isRequestInFlight
                      ? null
                      : controller.refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final searchWidth = constraints.maxWidth < 320
                    ? constraints.maxWidth
                    : 320.0;
                final filterWidth = constraints.maxWidth < 200
                    ? constraints.maxWidth
                    : 200.0;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: searchWidth,
                      child: TextField(
                        key: const Key('teacherHomeworkSearchField'),
                        controller: _searchController,
                        maxLength: TeacherHomeworkListQuery.maxSearchLength,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: 'Search Homework',
                          errorText: state.searchErrorText,
                          counterText: '',
                        ),
                        onChanged: controller.updateSearchDraft,
                        onSubmitted: (_) => controller.submitSearch(),
                      ),
                    ),
                    IconButton.filledTonal(
                      key: const Key('teacherHomeworkSearchButton'),
                      tooltip: 'Search Homework',
                      onPressed: controller.submitSearch,
                      icon: const Icon(Icons.search),
                    ),
                    SizedBox(
                      width: filterWidth,
                      child: _HomeworkFilter<TeacherHomeworkStatus>(
                        key: const Key('teacherHomeworkStatusFilter'),
                        label: 'Homework status',
                        value: state.query.status,
                        allLabel: 'All statuses',
                        options: const [
                          TeacherHomeworkStatus.draft,
                          TeacherHomeworkStatus.active,
                          TeacherHomeworkStatus.closed,
                          TeacherHomeworkStatus.archived,
                        ],
                        optionLabel: teacherHomeworkStatusLabel,
                        onChanged: controller.setStatus,
                      ),
                    ),
                    SizedBox(
                      width: filterWidth,
                      child: _HomeworkFilter<TeacherHomeworkAssignmentMode>(
                        key: const Key('teacherHomeworkAssignmentFilter'),
                        label: 'Homework assignment',
                        value: state.query.assignmentMode,
                        allLabel: 'All assignments',
                        options: const [
                          TeacherHomeworkAssignmentMode.group,
                          TeacherHomeworkAssignmentMode.selectedStudents,
                        ],
                        optionLabel: teacherHomeworkAssignmentLabel,
                        onChanged: controller.setAssignmentMode,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (state.status == TeacherHomeworkListStatus.refreshing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                key: Key('teacherHomeworkRefreshing'),
                semanticsLabel: 'Refreshing Homework',
              ),
            ],
            if (state.isStale) ...[
              const SizedBox(height: 12),
              const Text(
                'The displayed Homework may be out of date.',
                key: Key('teacherHomeworkStaleMessage'),
              ),
            ],
            const SizedBox(height: 12),
            _HomeworkListBody(
              topicId: widget.topicId,
              state: state,
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

class _HomeworkFilter<T> extends StatelessWidget {
  const _HomeworkFilter({
    required this.label,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T? value;
  final String allLabel;
  final List<T> options;
  final String Function(T value) optionLabel;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isExpanded: true,
          onChanged: onChanged,
          items: [
            DropdownMenuItem<T?>(value: null, child: Text(allLabel)),
            for (final option in options)
              DropdownMenuItem<T?>(
                value: option,
                child: Text(optionLabel(option)),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeworkListBody extends StatelessWidget {
  const _HomeworkListBody({
    required this.topicId,
    required this.state,
    required this.onRetry,
    required this.onPrevious,
    required this.onNext,
  });

  final String topicId;
  final TeacherHomeworkListState state;
  final VoidCallback onRetry;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    if ((state.status == TeacherHomeworkListStatus.initial ||
            state.status == TeacherHomeworkListStatus.loading) &&
        state.result == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(
            key: Key('teacherHomeworkLoading'),
            semanticsLabel: 'Loading Homework',
          ),
        ),
      );
    }

    if (state.status == TeacherHomeworkListStatus.error &&
        state.result == null) {
      return _HomeworkListError(onRetry: onRetry);
    }

    final result = state.result;
    if (result == null) {
      return _HomeworkListError(onRetry: onRetry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.status == TeacherHomeworkListStatus.error) ...[
          _HomeworkListError(onRetry: onRetry),
          const SizedBox(height: 12),
        ],
        if (result.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              state.hasActiveFilters
                  ? 'No Homework matches the current filters.'
                  : 'No Homework has been created for this Topic yet.',
              key: const Key('teacherHomeworkEmpty'),
            ),
          )
        else
          for (var index = 0; index < result.items.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _HomeworkRow(topicId: topicId, homework: result.items[index]),
          ],
        const SizedBox(height: 14),
        _HomeworkPagination(
          result: result,
          canGoPrevious: state.canGoPrevious,
          canGoNext: state.canGoNext,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
      ],
    );
  }
}

class _HomeworkRow extends StatelessWidget {
  const _HomeworkRow({required this.topicId, required this.homework});

  final String topicId;
  final TeacherHomeworkSummary homework;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open Homework ${homework.title}',
      child: Card.outlined(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('teacherHomeworkCard${homework.id}'),
          onTap: () => context.push(
            AppRoutePaths.teacherHomeworkDetailLocation(topicId, homework.id),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  homework.title,
                  softWrap: true,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(teacherHomeworkStatusLabel(homework.status)),
                    ),
                    Chip(
                      label: Text(
                        teacherHomeworkAssignmentLabel(homework.assignmentMode),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Questions: ${homework.questionCount}'),
                Text(
                  'Total points: '
                  '${formatTeacherHomeworkPoints(homework.totalPossiblePoints)}',
                ),
                Text(
                  'Deadline: '
                  '${formatTeacherHomeworkDeadline(homework.deadlineAt, homework.institutionTimezone)}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeworkPagination extends StatelessWidget {
  const _HomeworkPagination({
    required this.result,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final TeacherHomeworkList result;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        OutlinedButton(
          key: const Key('teacherHomeworkPreviousButton'),
          onPressed: canGoPrevious ? onPrevious : null,
          child: const Text('Previous'),
        ),
        Text(
          'Page ${result.pagination.page} of ${result.pagination.lastPage}',
          key: const Key('teacherHomeworkPageLabel'),
        ),
        OutlinedButton(
          key: const Key('teacherHomeworkNextButton'),
          onPressed: canGoNext ? onNext : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}

class _HomeworkListError extends StatelessWidget {
  const _HomeworkListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Homework could not be loaded.',
          key: Key('teacherHomeworkError'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('teacherHomeworkRetryButton'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
