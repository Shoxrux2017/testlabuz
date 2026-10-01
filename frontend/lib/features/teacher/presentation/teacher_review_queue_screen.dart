import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../../core/scoring/score_display.dart';
import '../../auth/application/auth_session_controller.dart';
import '../application/teacher_review_queue_controller.dart';
import '../application/teacher_review_queue_state.dart';
import '../application/teacher_session_key.dart';
import '../domain/teacher_submission.dart';
import '../domain/teacher_submission_list_query.dart';
import 'teacher_topic_formatters.dart';

/// The desktop review queue (`S09-FE-002A`); a submission opens in `S09-FE-003`.
class TeacherReviewQueueScreen extends ConsumerWidget {
  const TeacherReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(teacherReviewQueueControllerProvider);
    final controller = ref.read(teacherReviewQueueControllerProvider.notifier);
    final timezone = TeacherSessionSnapshot.fromSession(
      ref.watch(authSessionControllerProvider),
      ref.watch(appDeviceSurfaceProvider),
    ).eligibleKey?.institutionTimezone;

    return Scaffold(
      key: const Key('teacherReviewQueueScreen'),
      appBar: AppBar(
        title: const Text('Review queue'),
        leading: IconButton(
          key: const Key('teacherReviewQueueBackButton'),
          tooltip: 'Back to Teacher workspace',
          onPressed: () => context.go(AppRoutePaths.teacher),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            key: const Key('teacherReviewQueueRefreshButton'),
            tooltip: 'Refresh review queue',
            onPressed: state.isRequestInFlight
                ? null
                : state.status == TeacherReviewQueueStatus.error
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
                  _QueueFilters(state: state, controller: controller),
                  const SizedBox(height: 16),
                  if (state.status == TeacherReviewQueueStatus.refreshing) ...[
                    const LinearProgressIndicator(
                      semanticsLabel: 'Refreshing review queue',
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (state.isStale) ...[
                    MaterialBanner(
                      key: const Key('teacherReviewQueueStaleMessage'),
                      content: const Text(
                        'The displayed review queue may be out of date.',
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
                  _QueueBody(
                    state: state,
                    timezone: timezone,
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

enum _StatusOption {
  waiting('Waiting for review'),
  pending('Automatic checking pending'),
  checked('Checked'),
  all('All statuses');

  const _StatusOption(this.label);

  final String label;

  TeacherSubmissionCheckingFilter? get filter => switch (this) {
    waiting => TeacherSubmissionCheckingFilter.waitingForTeacherReview,
    pending => TeacherSubmissionCheckingFilter.automaticCheckingPending,
    checked => TeacherSubmissionCheckingFilter.checked,
    all => null,
  };

  static _StatusOption of(TeacherSubmissionCheckingFilter? filter) =>
      values.firstWhere((option) => option.filter == filter);
}

enum _TypeOption {
  all('All tasks', null),
  homework('Homework', TeacherSubmissionTaskType.homework),
  blitz('Blitz', TeacherSubmissionTaskType.blitz);

  const _TypeOption(this.label, this.type);

  final String label;
  final TeacherSubmissionTaskType? type;

  static _TypeOption of(TeacherSubmissionTaskType? type) =>
      values.firstWhere((option) => option.type == type);
}

enum _OfficialOption {
  both('Official and practice', null),
  officialOnly('Official only', true),
  practiceOnly('Practice only', false);

  const _OfficialOption(this.label, this.official);

  final String label;
  final bool? official;

  static _OfficialOption of(bool? official) =>
      values.firstWhere((option) => option.official == official);
}

const _sortLabels = {
  TeacherSubmissionSort.recommended: 'Recommended order',
  TeacherSubmissionSort.finalizedAt: 'Finalized time',
  TeacherSubmissionSort.studentName: 'Student name',
  TeacherSubmissionSort.reviewDueAt: 'Review deadline',
};

class _QueueFilters extends StatelessWidget {
  const _QueueFilters({required this.state, required this.controller});

  final TeacherReviewQueueState state;
  final TeacherReviewQueueController controller;

  @override
  Widget build(BuildContext context) {
    final query = state.query;
    final ascending = query.direction == TeacherSubmissionSortDirection.asc;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Dropdown<_StatusOption>(
          key: const Key('teacherReviewQueueStatusFilter'),
          label: 'Status',
          value: _StatusOption.of(query.checkingStatus),
          values: _StatusOption.values,
          labelOf: (option) => option.label,
          onChanged: (option) => controller.setCheckingStatus(option.filter),
        ),
        _Dropdown<_TypeOption>(
          key: const Key('teacherReviewQueueTypeFilter'),
          label: 'Task',
          value: _TypeOption.of(query.type),
          values: _TypeOption.values,
          labelOf: (option) => option.label,
          onChanged: (option) => controller.setType(option.type),
        ),
        _Dropdown<_OfficialOption>(
          key: const Key('teacherReviewQueueOfficialFilter'),
          label: 'Official',
          value: _OfficialOption.of(query.official),
          values: _OfficialOption.values,
          labelOf: (option) => option.label,
          onChanged: (option) => controller.setOfficial(option.official),
        ),
        FilterChip(
          key: const Key('teacherReviewQueueOverdueFilter'),
          label: const Text('Overdue only'),
          selected: query.overdueOnly,
          onSelected: controller.setOverdueOnly,
        ),
        _Dropdown<TeacherSubmissionSort>(
          key: const Key('teacherReviewQueueSortFilter'),
          label: 'Sort',
          value: query.sort,
          values: TeacherSubmissionSort.values,
          labelOf: (sort) => _sortLabels[sort]!,
          onChanged: controller.setSort,
        ),
        OutlinedButton.icon(
          key: const Key('teacherReviewQueueDirectionButton'),
          onPressed: query.sort == TeacherSubmissionSort.recommended
              ? null
              : () => controller.setDirection(
                  ascending
                      ? TeacherSubmissionSortDirection.desc
                      : TeacherSubmissionSortDirection.asc,
                ),
          icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
          label: Text(ascending ? 'Ascending' : 'Descending'),
        ),
        TextButton.icon(
          key: const Key('teacherReviewQueueClearFiltersButton'),
          onPressed: query == const TeacherSubmissionListQuery.initial()
              ? null
              : controller.clearFilters,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Clear filters'),
        ),
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            items: [
              for (final option in values)
                DropdownMenuItem<T>(
                  value: option,
                  child: Text(labelOf(option)),
                ),
            ],
            onChanged: (selected) {
              if (selected != null) {
                onChanged(selected);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _QueueBody extends StatelessWidget {
  const _QueueBody({
    required this.state,
    required this.timezone,
    required this.onRetry,
    required this.onPrevious,
    required this.onNext,
  });

  final TeacherReviewQueueState state;
  final String? timezone;
  final VoidCallback onRetry;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    if (result == null) {
      if (state.status == TeacherReviewQueueStatus.error) {
        return Column(
          children: [
            const Text('The review queue could not be loaded.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('teacherReviewQueueRetryButton'),
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
            key: Key('teacherReviewQueueLoading'),
            semanticsLabel: 'Loading review queue',
          ),
        ),
      );
    }

    final pagination = result.pagination;
    final empty = result.items.isEmpty;
    // A later page can empty while its items leave the filter; paging stays.
    final showsPaging = !empty || pagination.page > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (empty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              state.query == const TeacherSubmissionListQuery.initial()
                  ? 'No submissions are waiting for review.'
                  : 'No submissions match these filters.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final submission in result.items) ...[
          _QueueRow(submission: submission, timezone: timezone),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        if (showsPaging)
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                pagination.total == 1
                    ? '1 submission'
                    : '${pagination.total} submissions',
              ),
              Text('Page ${pagination.page} of ${pagination.lastPage}'),
              OutlinedButton(
                key: const Key('teacherReviewQueuePreviousButton'),
                onPressed: state.canGoPrevious ? onPrevious : null,
                child: const Text('Previous'),
              ),
              OutlinedButton(
                key: const Key('teacherReviewQueueNextButton'),
                onPressed: state.canGoNext ? onNext : null,
                child: const Text('Next'),
              ),
            ],
          ),
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.submission, required this.timezone});

  final TeacherSubmission submission;
  final String? timezone;

  @override
  Widget build(BuildContext context) {
    final answers = submission.waitingAnswers + submission.reviewedAnswers;
    final details = [
      if (answers > 0)
        'Reviewed ${submission.reviewedAnswers} of $answers '
            '${answers == 1 ? 'answer' : 'answers'}',
      if (submission.reviewDueAt case final reviewDueAt?)
        'Review by ${_formatTime(reviewDueAt)}',
      if (submission.normalizedScore case final score?)
        'Score ${formatScoreOneDecimal(score)}',
    ];

    return Card(
      key: Key('teacherReviewQueueRow:${submission.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  submission.studentName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Chip(
                  label: Text(submission.official ? 'Official' : 'Practice'),
                ),
                if (!submission.officialScoreEligible)
                  const Chip(label: Text('Invalidated attempt')),
                if (submission.reviewOverdue)
                  const Chip(label: Text('Overdue')),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_typeLabel(submission.taskType)} · ${submission.taskTitle} · '
              '${submission.topicTitle} · ${submission.groupName}',
            ),
            Text(
              'Attempt ${submission.attemptNumber} · '
              '${_statusLabel(submission.status)} · '
              'Finalized ${_formatTime(submission.finalizedAt)}',
            ),
            if (details.isNotEmpty) Text(details.join(' · ')),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime instant) {
    final zone = timezone;
    return (zone == null ? null : formatInstitutionInstant(instant, zone)) ??
        formatUtcInstant(instant);
  }
}

String _typeLabel(TeacherSubmissionTaskType type) => switch (type) {
  TeacherSubmissionTaskType.homework => 'Homework',
  TeacherSubmissionTaskType.blitz => 'Blitz',
};

String _statusLabel(TeacherSubmissionStatus status) => switch (status) {
  TeacherSubmissionStatus.waitingForTeacherReview => 'Waiting for review',
  TeacherSubmissionStatus.checked => 'Checked',
  TeacherSubmissionStatus.submitted ||
  TeacherSubmissionStatus.timedOutFinalized => 'Automatic checking pending',
};
