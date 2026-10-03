import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../application/teacher_topic_result_list_controller.dart';
import '../application/teacher_topic_result_list_state.dart';
import '../domain/teacher_topic_result.dart';
import 'teacher_topic_result_formatters.dart';
import 'teacher_workspace_list_widgets.dart';

/// The Topic results list on desktop and mobile (`S10-FE-D1`): status and
/// category filters with the cohort counts, pages, and a row per Student.
class TeacherTopicResultsScreen extends ConsumerWidget {
  const TeacherTopicResultsScreen({required this.topicId, super.key});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = teacherTopicResultListControllerProvider(
      topicId.toLowerCase(),
    );
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    // The nested route normally pops to its Topic; `go` covers an empty stack.
    void backToTopic() {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go(AppRoutePaths.teacherTopicDetailLocation(topicId));
    }

    return Scaffold(
      key: const Key('teacherTopicResultsScreen'),
      appBar: AppBar(
        title: const Text('Topic results'),
        leading: IconButton(
          key: const Key('teacherTopicResultsBackButton'),
          tooltip: 'Back to Topic',
          onPressed: backToTopic,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            key: const Key('teacherTopicResultsRefreshButton'),
            tooltip: 'Refresh results',
            onPressed: state.isRequestInFlight
                ? null
                : state.status == TeacherTopicResultListStatus.error
                ? controller.retry
                : controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ResultFilters(state: state, controller: controller),
                  const SizedBox(height: 16),
                  if (state.status ==
                      TeacherTopicResultListStatus.refreshing) ...[
                    const LinearProgressIndicator(
                      semanticsLabel: 'Refreshing Topic results',
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (state.isStale) ...[
                    MaterialBanner(
                      key: const Key('teacherTopicResultsStaleMessage'),
                      content: const Text(
                        'The displayed results may be out of date.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: controller.retry,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  _ResultsBody(
                    topicId: topicId,
                    state: state,
                    onRetry: controller.retry,
                    onPrevious: controller.previousPage,
                    onNext: controller.nextPage,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultFilters extends StatelessWidget {
  const _ResultFilters({required this.state, required this.controller});

  final TeacherTopicResultListState state;
  final TeacherTopicResultListController controller;

  @override
  Widget build(BuildContext context) {
    final counts = state.counts;
    String withCount(String label, int? count) =>
        count == null ? label : '$label ($count)';

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ResultFilter<TeacherTopicResultStatus>(
          key: const Key('teacherTopicResultsStatusFilter'),
          label: 'Status',
          value: state.query.status,
          allLabel: withCount('All statuses', counts?.total),
          options: TeacherTopicResultStatus.values,
          optionLabel: (status) => withCount(
            teacherTopicResultStatusLabel(status),
            counts?.of(status),
          ),
          onChanged: controller.setStatus,
        ),
        _ResultFilter<TeacherTopicResultCategoryCode>(
          key: const Key('teacherTopicResultsCategoryFilter'),
          label: 'Category',
          value: state.query.category,
          allLabel: 'All categories',
          options: TeacherTopicResultCategoryCode.values,
          optionLabel: teacherTopicResultCategoryFilterLabel,
          onChanged: controller.setCategory,
        ),
        TextButton.icon(
          key: const Key('teacherTopicResultsClearFilters'),
          onPressed: state.query.isFiltered ? controller.clearFilters : null,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Clear filters'),
        ),
      ],
    );
  }
}

class _ResultFilter<T> extends StatelessWidget {
  const _ResultFilter({
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
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
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
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.topicId,
    required this.state,
    required this.onRetry,
    required this.onPrevious,
    required this.onNext,
  });

  final String topicId;
  final TeacherTopicResultListState state;
  final VoidCallback onRetry;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    if (result == null) {
      final failure = state.failure;
      if (state.status == TeacherTopicResultListStatus.error &&
          failure != null) {
        return Column(
          children: [
            Text(
              teacherTopicResultsFailureMessage(failure),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('teacherTopicResultsRetryButton'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        );
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(
            key: Key('teacherTopicResultsLoading'),
            semanticsLabel: 'Loading Topic results',
          ),
        ),
      );
    }

    final pagination = result.pagination;
    final empty = result.items.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (empty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              state.query.isFiltered
                  ? 'No results match these filters.'
                  : teacherTopicResultsEmptyMessage,
              textAlign: TextAlign.center,
            ),
          ),
        for (final item in result.items) ...[
          _ResultRow(topicId: topicId, result: item),
          const SizedBox(height: 8),
        ],
        // A later page can empty while its rows leave the filter; paging stays.
        if (!empty || pagination.page > 1) ...[
          const SizedBox(height: 8),
          Text(
            pagination.total == 1
                ? '1 Student'
                : '${pagination.total} Students',
          ),
          const SizedBox(height: 8),
          TeacherListPaginationControls(
            pagination: pagination,
            canPrevious: state.canGoPrevious,
            canNext: state.canGoNext,
            onPrevious: onPrevious,
            onNext: onNext,
          ),
        ],
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.topicId, required this.result});

  final String topicId;
  final TeacherTopicResult result;

  @override
  Widget build(BuildContext context) {
    final scores = teacherTopicResultScoresLine(result);
    final missing = result.missingComponent;
    final category = result.category;
    final visibility = result.visibility;

    return Card(
      key: Key('teacherTopicResultRow:${result.studentId}'),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: 'Open the result of ${result.studentName}',
        child: InkWell(
          onTap: () => context.push(
            AppRoutePaths.teacherTopicResultDetailLocation(
              topicId,
              result.studentId,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.studentName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(teacherTopicResultLabel(result)),
                if (missing != null)
                  Text(teacherTopicResultMissingLabel(missing)),
                if (scores != null) Text(scores),
                if (category != null) Text('Category: ${category.label}'),
                Text(
                  'Student: '
                  '${teacherTopicResultVisibilityLabel(visibility.studentVisible)}'
                  ' · Parents: '
                  '${teacherTopicResultVisibilityLabel(visibility.parentVisible)}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
