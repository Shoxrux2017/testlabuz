import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../application/teacher_topic_list_controller.dart';
import '../application/teacher_topic_list_state.dart';
import '../domain/teacher_group.dart';
import '../domain/teacher_topic.dart';
import '../domain/teacher_topic_list_query.dart';
import 'teacher_workspace_list_widgets.dart';

const _controlSpacing = 12.0;

class TeacherTopicsSection extends ConsumerWidget {
  const TeacherTopicsSection({
    required this.state,
    required this.searchController,
    super.key,
  });

  final TeacherTopicListState state;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(teacherTopicListControllerProvider.notifier);
    final canChangeFilters =
        state.searchErrorText == null && !state.isRequestInFlight;

    return TeacherWorkspaceSection(
      key: const Key('teacherTopicsSection'),
      title: 'Topics',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('teacherTopicSearchField'),
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Search topics',
              errorText: state.searchErrorText,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            maxLength: TeacherTopicListQuery.maxSearchLength,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            textInputAction: TextInputAction.search,
            onChanged: controller.updateSearchDraft,
            onSubmitted: (_) => controller.commitSearchNow(),
          ),
          Wrap(
            spacing: _controlSpacing,
            runSpacing: _controlSpacing,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 190,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Topic status',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TeacherTopicStatus?>(
                      key: const Key('teacherTopicStatusFilter'),
                      value: state.query.status,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<TeacherTopicStatus?>(
                          value: null,
                          child: Text('All statuses'),
                        ),
                        for (final status in TeacherTopicStatus.values)
                          DropdownMenuItem<TeacherTopicStatus?>(
                            value: status,
                            child: Text(teacherTopicStatusLabel(status)),
                          ),
                      ],
                      onChanged: canChangeFilters ? controller.setStatus : null,
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('teacherAllGroupsButton'),
                onPressed: canChangeFilters && state.query.groupId != null
                    ? controller.clearGroupFilter
                    : null,
                icon: const Icon(Icons.groups_outlined),
                label: const Text('All groups'),
              ),
              if (state.selectedGroup case final group?)
                Chip(
                  key: const Key('teacherSelectedGroupChip'),
                  label: Text(
                    'Group: ${group.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: canChangeFilters
                      ? controller.clearGroupFilter
                      : null,
                ),
              OutlinedButton.icon(
                key: const Key('teacherTopicClearFiltersButton'),
                onPressed: state.canClearFilters && !state.isRequestInFlight
                    ? controller.clearFilters
                    : null,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear filters'),
              ),
              OutlinedButton.icon(
                key: const Key('teacherTopicRefreshButton'),
                onPressed: canChangeFilters ? controller.refresh : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TopicListBody(state: state),
        ],
      ),
    );
  }
}

class _TopicListBody extends ConsumerWidget {
  const _TopicListBody({required this.state});

  final TeacherTopicListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(teacherTopicListControllerProvider.notifier);

    return switch (state.status) {
      TeacherTopicListStatus.initial ||
      TeacherTopicListStatus.loading => const TeacherListLoading(
        key: Key('teacherTopicInitialLoading'),
        label: 'Loading topics',
      ),
      TeacherTopicListStatus.queryLoading => const TeacherListLoading(
        key: Key('teacherTopicQueryLoading'),
        label: 'Loading matching topics',
      ),
      TeacherTopicListStatus.error => TeacherListError(
        key: const Key('teacherTopicListError'),
        title: 'Unable to load topics',
        message: _topicFailureMessage(state.failure!),
        isRetrying: state.isRetryInFlight,
        onRetry: controller.retry,
      ),
      TeacherTopicListStatus.globalEmpty => const TeacherListEmpty(
        key: Key('teacherTopicGlobalEmpty'),
        title: 'No topics yet',
        message: 'No readable Topics are available yet.',
      ),
      TeacherTopicListStatus.filteredEmpty => TeacherListEmpty(
        key: const Key('teacherTopicFilteredEmpty'),
        title: 'No matching topics',
        message: 'No Topics match the current filters.',
        action: OutlinedButton.icon(
          onPressed: controller.clearFilters,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Clear filters'),
        ),
      ),
      TeacherTopicListStatus.emptyPage => TeacherEmptyPage(
        key: const Key('teacherTopicEmptyPage'),
        onFirstPage: controller.returnToFirstPage,
      ),
      TeacherTopicListStatus.refreshing ||
      TeacherTopicListStatus.data => _TopicListData(
        state: state,
        isRefreshing: state.status == TeacherTopicListStatus.refreshing,
      ),
    };
  }
}

class _TopicListData extends ConsumerWidget {
  const _TopicListData({required this.state, required this.isRefreshing});

  final TeacherTopicListState state;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(teacherTopicListControllerProvider.notifier);
    final result = state.result!;

    return Column(
      key: const Key('teacherTopicListData'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isRefreshing) ...[
          const LinearProgressIndicator(
            key: Key('teacherTopicRefreshing'),
            semanticsLabel: 'Refreshing topics',
          ),
          const SizedBox(height: 12),
        ],
        for (final topic in result.topics) ...[
          _TopicCard(topic: topic),
          const SizedBox(height: 8),
        ],
        TeacherListPaginationControls(
          pagination: result.pagination,
          canPrevious: state.canGoPrevious,
          canNext: state.canGoNext,
          onPrevious: controller.previousPage,
          onNext: controller.nextPage,
        ),
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});

  final TeacherTopic topic;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('teacherTopicCard${topic.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(topic.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('Subject: ${topic.subject}'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(
                    'Topic: ${teacherTopicStatusLabel(topic.status)}',
                  ),
                ),
                Chip(
                  label: Text(
                    'Group: ${topic.group.name} '
                    '(${_groupStatusLabel(topic.group.status)})',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _topicFailureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.forbidden => 'You do not have permission to view Topics.',
    ApiErrorCodes.validationFailed =>
      'The Topic list request could not be completed.',
    ApiErrorCodes.resourceNotFound => 'The Topic list could not be loaded.',
    ApiErrorCodes.rateLimited => 'Too many requests. Wait before trying again.',
    ApiErrorCodes.serverError => 'The Topic list could not be loaded.',
    _ => switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The Topic list request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected Topic list response.',
      ApiFailureKind.cancelled => 'The Topic list request was cancelled.',
      ApiFailureKind.server ||
      ApiFailureKind.validation ||
      ApiFailureKind.unknown => 'The Topic list could not be loaded.',
    },
  };
}

String teacherTopicStatusLabel(TeacherTopicStatus status) {
  return switch (status) {
    TeacherTopicStatus.draft => 'Draft',
    TeacherTopicStatus.active => 'Active',
    TeacherTopicStatus.closed => 'Closed',
    TeacherTopicStatus.archived => 'Archived',
  };
}

String _groupStatusLabel(TeacherGroupStatus status) {
  return switch (status) {
    TeacherGroupStatus.active => 'Active',
    TeacherGroupStatus.archived => 'Archived',
  };
}
