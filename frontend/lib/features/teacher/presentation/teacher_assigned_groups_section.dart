import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../application/teacher_group_list_controller.dart';
import '../application/teacher_group_list_state.dart';
import '../application/teacher_topic_list_controller.dart';
import '../domain/teacher_group.dart';
import '../domain/teacher_group_list_query.dart';
import 'teacher_workspace_list_widgets.dart';

const _controlSpacing = 12.0;

class TeacherAssignedGroupsSection extends ConsumerWidget {
  const TeacherAssignedGroupsSection({
    required this.state,
    required this.searchController,
    super.key,
  });

  final TeacherGroupListState state;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(teacherGroupListControllerProvider.notifier);

    return TeacherWorkspaceSection(
      key: const Key('teacherAssignedGroupsSection'),
      title: 'Assigned Groups',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('teacherGroupSearchField'),
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Search assigned groups',
              errorText: state.searchErrorText,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            maxLength: TeacherGroupListQuery.maxSearchLength,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            textInputAction: TextInputAction.search,
            onChanged: controller.updateSearchDraft,
            onSubmitted: (_) => controller.commitSearchNow(),
          ),
          Wrap(
            spacing: _controlSpacing,
            runSpacing: _controlSpacing,
            children: [
              OutlinedButton.icon(
                key: const Key('teacherGroupClearSearchButton'),
                onPressed: state.canClearSearch && !state.isRequestInFlight
                    ? controller.clearSearch
                    : null,
                icon: const Icon(Icons.clear),
                label: const Text('Clear search'),
              ),
              OutlinedButton.icon(
                key: const Key('teacherGroupRefreshButton'),
                onPressed:
                    state.searchErrorText == null && !state.isRequestInFlight
                    ? controller.refresh
                    : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _GroupListBody(state: state),
        ],
      ),
    );
  }
}

class _GroupListBody extends ConsumerWidget {
  const _GroupListBody({required this.state});

  final TeacherGroupListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(teacherGroupListControllerProvider.notifier);

    return switch (state.status) {
      TeacherGroupListStatus.initial ||
      TeacherGroupListStatus.loading => const TeacherListLoading(
        key: Key('teacherGroupInitialLoading'),
        label: 'Loading assigned groups',
      ),
      TeacherGroupListStatus.queryLoading => const TeacherListLoading(
        key: Key('teacherGroupQueryLoading'),
        label: 'Loading matching assigned groups',
      ),
      TeacherGroupListStatus.error => TeacherListError(
        key: const Key('teacherGroupListError'),
        title: 'Unable to load assigned groups',
        message: _groupFailureMessage(state.failure!),
        canRetry: state.searchErrorText == null,
        isRetrying: state.isRetryInFlight,
        onRetry: controller.retry,
      ),
      TeacherGroupListStatus.globalEmpty => const TeacherListEmpty(
        key: Key('teacherGroupGlobalEmpty'),
        title: 'No active assigned groups',
        message: 'No active Group is currently assigned to this Teacher.',
      ),
      TeacherGroupListStatus.filteredEmpty => TeacherListEmpty(
        key: const Key('teacherGroupFilteredEmpty'),
        title: 'No matching assigned groups',
        message: 'No assigned Groups match the current search.',
        action: OutlinedButton.icon(
          onPressed: controller.clearSearch,
          icon: const Icon(Icons.clear),
          label: const Text('Clear search'),
        ),
      ),
      TeacherGroupListStatus.emptyPage => TeacherEmptyPage(
        key: const Key('teacherGroupEmptyPage'),
        onFirstPage: controller.returnToFirstPage,
      ),
      TeacherGroupListStatus.refreshing ||
      TeacherGroupListStatus.data => _GroupListData(
        state: state,
        isRefreshing: state.status == TeacherGroupListStatus.refreshing,
      ),
    };
  }
}

class _GroupListData extends ConsumerWidget {
  const _GroupListData({required this.state, required this.isRefreshing});

  final TeacherGroupListState state;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(teacherGroupListControllerProvider.notifier);
    final topicState = ref.watch(teacherTopicListControllerProvider);
    final topicController = ref.read(
      teacherTopicListControllerProvider.notifier,
    );
    final result = state.result!;

    return Column(
      key: const Key('teacherGroupListData'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isRefreshing) ...[
          const LinearProgressIndicator(
            key: Key('teacherGroupRefreshing'),
            semanticsLabel: 'Refreshing assigned groups',
          ),
          const SizedBox(height: 12),
        ],
        for (final group in result.groups) ...[
          _GroupCard(
            group: group,
            selected: topicState.query.groupId == group.id,
            enabled:
                topicState.searchErrorText == null &&
                !topicState.isRequestInFlight,
            onSelected: () => topicController.selectGroup(group),
          ),
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

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final TeacherGroupSummary group;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      label: '${group.name}, select as Topic group filter',
      child: Card(
        key: ValueKey('teacherGroupCard${group.id}'),
        margin: EdgeInsets.zero,
        color: selected ? colorScheme.secondaryContainer : null,
        shape: RoundedRectangleBorder(
          side: selected
              ? BorderSide(color: colorScheme.primary, width: 2)
              : BorderSide(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: enabled ? onSelected : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (group.level case final level?) ...[
                  const SizedBox(height: 4),
                  Text('Level: $level'),
                ],
                if (group.subjectDirection case final direction?) ...[
                  const SizedBox(height: 4),
                  Text('Subject direction: $direction'),
                ],
                if (selected) ...[
                  const SizedBox(height: 6),
                  const Text('Selected for Topics'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _groupFailureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.forbidden =>
      'You do not have permission to view assigned groups.',
    ApiErrorCodes.validationFailed =>
      'The assigned Group request could not be completed.',
    ApiErrorCodes.resourceNotFound =>
      'The assigned Group list could not be loaded.',
    ApiErrorCodes.rateLimited => 'Too many requests. Wait before trying again.',
    ApiErrorCodes.serverError => 'The assigned Group list could not be loaded.',
    _ => switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The assigned Group request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected assigned Group response.',
      ApiFailureKind.cancelled => 'The assigned Group request was cancelled.',
      ApiFailureKind.server ||
      ApiFailureKind.validation ||
      ApiFailureKind.unknown => 'The assigned Group list could not be loaded.',
    },
  };
}
