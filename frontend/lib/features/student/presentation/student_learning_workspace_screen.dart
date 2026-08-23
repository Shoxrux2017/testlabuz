import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/auth_user.dart';
import '../application/student_session_key.dart';
import '../application/student_topic_list_controller.dart';
import '../application/student_topic_list_state.dart';
import '../domain/student_topic.dart';
import '../domain/student_topic_list.dart';
import '../domain/student_topic_list_query.dart';
import 'student_topic_formatters.dart';

class StudentLearningWorkspaceScreen extends ConsumerStatefulWidget {
  const StudentLearningWorkspaceScreen({super.key});

  @override
  ConsumerState<StudentLearningWorkspaceScreen> createState() =>
      _StudentLearningWorkspaceScreenState();
}

class _StudentLearningWorkspaceScreenState
    extends ConsumerState<StudentLearningWorkspaceScreen> {
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
    final session = ref.watch(authSessionControllerProvider);
    final surface = ref.watch(appDeviceSurfaceProvider);
    final user = session.user;
    if (session.status != AuthSessionStatus.authenticated || user == null) {
      return const _NeutralStudentWorkspace();
    }
    if (StudentSessionSnapshot.fromSession(session, surface).eligibleKey ==
        null) {
      return const _StudentWorkspaceUnavailable();
    }

    final listState = ref.watch(studentTopicListControllerProvider);
    _syncSearchController(listState.searchDraft);

    return Scaffold(
      key: const Key('studentLearningWorkspace'),
      body: SafeArea(
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StudentWorkspaceHeader(user: user),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final padding = constraints.maxWidth < 600 ? 12.0 : 20.0;
                    return SingleChildScrollView(
                      key: const Key('studentWorkspaceScroll'),
                      padding: EdgeInsets.all(padding),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1040),
                          child: _StudentTopicsWorkspace(
                            state: listState,
                            searchController: _searchController,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _syncSearchController(String value) {
    if (_searchController.text == value) {
      return;
    }
    _searchController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class _StudentWorkspaceHeader extends ConsumerWidget {
  const _StudentWorkspaceHeader({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Wrap(
        key: const Key('studentWorkspaceHeader'),
        spacing: 20,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TestLabUz',
                key: const Key('studentProductName'),
                style: textTheme.titleMedium,
              ),
              Text(
                'Student',
                key: const Key('studentRoleLabel'),
                style: textTheme.headlineSmall,
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current user: ${user.fullName}',
                  key: const Key('studentCurrentUser'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Institution: ${user.institution!.name}',
                  key: const Key('studentInstitutionName'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton.icon(
            key: const Key('entryLogoutButton'),
            onPressed: () {
              unawaited(
                ref.read(authSessionControllerProvider.notifier).signOut(),
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _StudentTopicsWorkspace extends ConsumerWidget {
  const _StudentTopicsWorkspace({
    required this.state,
    required this.searchController,
  });

  final StudentTopicListState state;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(studentTopicListControllerProvider.notifier);
    final canChangeQuery =
        state.searchErrorText == null && !state.isRequestInFlight;
    return Card(
      key: const Key('studentTopicsSection'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'My Topics',
                key: const Key('studentTopicsHeading'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('studentTopicSearchField'),
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search topics',
                errorText: state.searchErrorText,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              maxLength: StudentTopicListQuery.maxSearchLength,
              maxLengthEnforcement: MaxLengthEnforcement.none,
              textInputAction: TextInputAction.search,
              onChanged: controller.updateSearchDraft,
              onSubmitted: (_) => controller.commitSearchNow(),
            ),
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
                      child: DropdownButton<StudentTopicStatus?>(
                        key: const Key('studentTopicStatusFilter'),
                        value: state.query.status,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<StudentTopicStatus?>(
                            value: null,
                            child: Text('All'),
                          ),
                          for (final status in StudentTopicStatus.values)
                            DropdownMenuItem<StudentTopicStatus?>(
                              value: status,
                              child: Text(studentTopicStatusLabel(status)),
                            ),
                        ],
                        onChanged: canChangeQuery ? controller.setStatus : null,
                      ),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('studentTopicRefreshButton'),
                  onPressed: canChangeQuery ? controller.refresh : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                if (state.canClearFilters)
                  OutlinedButton.icon(
                    key: const Key('studentTopicClearFiltersButton'),
                    onPressed: state.isRequestInFlight
                        ? null
                        : controller.clearFilters,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Clear filters'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _StudentTopicListBody(state: state),
          ],
        ),
      ),
    );
  }
}

class _StudentTopicListBody extends ConsumerWidget {
  const _StudentTopicListBody({required this.state});

  final StudentTopicListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(studentTopicListControllerProvider.notifier);
    return switch (state.status) {
      StudentTopicListStatus.initial ||
      StudentTopicListStatus.loading => const _StudentListLoading(
        key: Key('studentTopicInitialLoading'),
        label: 'Loading Topics',
      ),
      StudentTopicListStatus.queryLoading => const _StudentListLoading(
        key: Key('studentTopicQueryLoading'),
        label: 'Loading matching Topics',
      ),
      StudentTopicListStatus.error => _StudentListError(
        failure: state.failure!,
        canRetry: state.searchErrorText == null,
        retrying: state.isRetryInFlight,
        onRetry: controller.retry,
      ),
      StudentTopicListStatus.globalEmpty => const _StudentListEmpty(
        key: Key('studentTopicGlobalEmpty'),
        message: 'No Topics are available yet.',
      ),
      StudentTopicListStatus.filteredEmpty => const _StudentListEmpty(
        key: Key('studentTopicFilteredEmpty'),
        message: 'No matching Topics.',
      ),
      StudentTopicListStatus.emptyPage => _StudentListEmpty(
        key: const Key('studentTopicEmptyPage'),
        message: 'This page is no longer available.',
        action: OutlinedButton(
          onPressed: controller.returnToFirstPage,
          child: const Text('Return to first page'),
        ),
      ),
      StudentTopicListStatus.refreshing ||
      StudentTopicListStatus.data => _StudentTopicListData(
        state: state,
        refreshing: state.status == StudentTopicListStatus.refreshing,
      ),
    };
  }
}

class _StudentTopicListData extends ConsumerWidget {
  const _StudentTopicListData({required this.state, required this.refreshing});

  final StudentTopicListState state;
  final bool refreshing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = state.result!;
    final controller = ref.read(studentTopicListControllerProvider.notifier);
    final timezone = ref
        .watch(authSessionControllerProvider)
        .user!
        .institution!
        .timezone;
    return Column(
      key: const Key('studentTopicListData'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (refreshing) ...[
          const LinearProgressIndicator(
            key: Key('studentTopicRefreshing'),
            semanticsLabel: 'Refreshing Topics',
          ),
          const SizedBox(height: 12),
        ],
        for (final topic in result.topics) ...[
          _StudentTopicCard(topic: topic, institutionTimezone: timezone),
          const SizedBox(height: 10),
        ],
        _StudentPaginationControls(
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

class _StudentTopicCard extends StatelessWidget {
  const _StudentTopicCard({
    required this.topic,
    required this.institutionTimezone,
  });

  final StudentTopicSummary topic;
  final String institutionTimezone;

  @override
  Widget build(BuildContext context) {
    final lesson = formatStudentInstitutionInstant(
      topic.lessonAt,
      institutionTimezone,
    );
    return Semantics(
      button: true,
      label: 'Open Topic ${topic.title}',
      child: Card(
        key: ValueKey('studentTopicCard${topic.id}'),
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () =>
              context.go(AppRoutePaths.studentTopicDetailLocation(topic.id)),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text('Subject: ${topic.subject}'),
                const SizedBox(height: 4),
                Text('Group: ${topic.group.name}'),
                if (topic.group.level case final level?) Text('Level: $level'),
                if (topic.group.subjectDirection case final direction?)
                  Text('Subject direction: $direction'),
                if (topic.lessonAt != null)
                  Text(
                    'Lesson time: '
                    '${lesson ?? 'Institution timezone unavailable'}',
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        'Topic: ${studentTopicStatusLabel(topic.status)}',
                      ),
                    ),
                    Chip(
                      label: Text(
                        'Group status: '
                        '${studentGroupStatusLabel(topic.group.status)}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentPaginationControls extends StatelessWidget {
  const _StudentPaginationControls({
    required this.pagination,
    required this.canPrevious,
    required this.canNext,
    required this.onPrevious,
    required this.onNext,
  });

  final StudentListPagination pagination;
  final bool canPrevious;
  final bool canNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('studentTopicPagination'),
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          onPressed: canPrevious ? onPrevious : null,
          child: const Text('Previous'),
        ),
        Text('Page ${pagination.page} of ${pagination.lastPage}'),
        OutlinedButton(
          onPressed: canNext ? onNext : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}

class _StudentListLoading extends StatelessWidget {
  const _StudentListLoading({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Semantics(
          label: label,
          liveRegion: true,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _StudentListEmpty extends StatelessWidget {
  const _StudentListEmpty({required this.message, super.key, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          if (action case final emptyAction?) ...[
            const SizedBox(height: 16),
            emptyAction,
          ],
        ],
      ),
    );
  }
}

class _StudentListError extends StatelessWidget {
  const _StudentListError({
    required this.failure,
    required this.canRetry,
    required this.retrying,
    required this.onRetry,
  });

  final ApiFailure failure;
  final bool canRetry;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('studentTopicListError'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 8),
          Text(
            'Unable to load Topics',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _studentListFailureMessage(failure),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('studentTopicListRetryButton'),
            onPressed: canRetry && !retrying ? onRetry : null,
            icon: retrying
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(retrying ? 'Retrying' : 'Retry'),
          ),
        ],
      ),
    );
  }
}

String _studentListFailureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.forbidden =>
      'You do not have permission to access Student Topics.',
    ApiErrorCodes.validationFailed =>
      'The Student Topic query could not be completed.',
    ApiErrorCodes.rateLimited => 'Too many requests. Try again later.',
    _ => switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The Student Topic request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected Student Topic response.',
      ApiFailureKind.cancelled => 'The Student Topic request was cancelled.',
      ApiFailureKind.server ||
      ApiFailureKind.validation ||
      ApiFailureKind.unknown => 'Student Topics could not be loaded.',
    },
  };
}

class _NeutralStudentWorkspace extends StatelessWidget {
  const _NeutralStudentWorkspace();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}

class _StudentWorkspaceUnavailable extends ConsumerWidget {
  const _StudentWorkspaceUnavailable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Session route unavailable',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  key: const Key('entryLogoutButton'),
                  onPressed: () {
                    unawaited(
                      ref
                          .read(authSessionControllerProvider.notifier)
                          .signOut(),
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
