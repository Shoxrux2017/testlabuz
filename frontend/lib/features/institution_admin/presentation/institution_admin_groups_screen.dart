import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../application/institution_group_list_controller.dart';
import '../application/institution_group_list_state.dart';
import '../domain/institution_group.dart';
import '../domain/institution_group_list.dart';
import '../domain/institution_group_list_query.dart';

const _pagePadding = 24.0;
const _sectionSpacing = 20.0;
const _controlSpacing = 12.0;
const _panelRadius = 8.0;
const _searchWidth = 320.0;
const _filterWidth = 180.0;
const _tableMinWidth = 1390.0;

class InstitutionAdminGroupsScreen extends ConsumerStatefulWidget {
  const InstitutionAdminGroupsScreen({super.key});

  @override
  ConsumerState<InstitutionAdminGroupsScreen> createState() =>
      _InstitutionAdminGroupsScreenState();
}

class _InstitutionAdminGroupsScreenState
    extends ConsumerState<InstitutionAdminGroupsScreen> {
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
    final state = ref.watch(institutionGroupListControllerProvider);
    _syncSearchController(state.searchDraft);
    final controller = ref.read(
      institutionGroupListControllerProvider.notifier,
    );

    return SingleChildScrollView(
      key: const Key('institutionGroupListSurface'),
      padding: const EdgeInsets.all(_pagePadding),
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              key: const Key('institutionGroupListHeader'),
              spacing: _controlSpacing,
              runSpacing: _controlSpacing,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Groups',
                  key: const Key('institutionGroupListHeading'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                FilledButton.icon(
                  key: const Key('institutionGroupCreateButton'),
                  onPressed: () => context.goNamed(
                    AppRouteNames.institutionAdminGroupCreate,
                  ),
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Create Group'),
                ),
              ],
            ),
            if (state.recoveryWarning case final warning?) ...[
              const SizedBox(height: 12),
              Semantics(
                key: const Key('institutionGroupCreateRecoveryWarning'),
                liveRegion: true,
                container: true,
                child: MaterialBanner(
                  content: Text(warning),
                  actions: const [SizedBox.shrink()],
                ),
              ),
            ],
            const SizedBox(height: _sectionSpacing),
            _GroupListToolbar(
              state: state,
              searchController: _searchController,
              onSearchChanged: controller.updateSearchDraft,
              onSearchSubmitted: controller.commitSearchNow,
              onStatusChanged: controller.setStatus,
              onClearFilters: controller.clearFilters,
              onRefresh: controller.refresh,
            ),
            const SizedBox(height: _sectionSpacing),
            _GroupListBody(
              state: state,
              onSort: controller.toggleSort,
              onRetry: controller.retry,
              onClearFilters: controller.clearFilters,
              onRefresh: controller.refresh,
              onPrevious: controller.previousPage,
              onNext: controller.nextPage,
              onFirstPage: controller.returnToFirstPage,
              onPerPageChanged: controller.setPerPage,
              onCreate: () =>
                  context.goNamed(AppRouteNames.institutionAdminGroupCreate),
              onOpenGroup: (group) => context.goNamed(
                AppRouteNames.institutionAdminGroupDetail,
                pathParameters: {
                  AppRoutePaths.institutionAdminGroupIdParameter: group.id,
                },
              ),
            ),
          ],
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

class _GroupListToolbar extends StatelessWidget {
  const _GroupListToolbar({
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onStatusChanged,
    required this.onClearFilters,
    required this.onRefresh,
  });

  final InstitutionGroupListState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<InstitutionGroupStatusFilter?> onStatusChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final canChangeQuery = state.canChangeQuery;
    final canClear = state.canClearFilters && !state.isRequestInFlight;

    return Wrap(
      key: const Key('institutionGroupListToolbar'),
      spacing: _controlSpacing,
      runSpacing: _controlSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: _searchWidth,
          child: TextField(
            key: const Key('institutionGroupSearchField'),
            controller: searchController,
            enabled: !state.isRequestInFlight,
            decoration: InputDecoration(
              labelText: 'Search groups',
              errorText: state.searchErrorText,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            maxLength: InstitutionGroupListQuery.maxSearchLength,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            textInputAction: TextInputAction.search,
            onChanged: onSearchChanged,
            onSubmitted: (_) => onSearchSubmitted(),
          ),
        ),
        SizedBox(
          width: _filterWidth,
          child: InputDecorator(
            key: const Key('institutionGroupStatusFilter'),
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<InstitutionGroupStatusFilter?>(
                value: state.query.status,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<InstitutionGroupStatusFilter?>(
                    value: null,
                    child: Text('All statuses'),
                  ),
                  for (final status in InstitutionGroupStatusFilter.values)
                    DropdownMenuItem<InstitutionGroupStatusFilter?>(
                      value: status,
                      child: Text(_statusFilterLabel(status)),
                    ),
                ],
                onChanged: canChangeQuery ? onStatusChanged : null,
              ),
            ),
          ),
        ),
        OutlinedButton.icon(
          key: const Key('institutionGroupClearFiltersButton'),
          onPressed: canClear ? onClearFilters : null,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Clear filters'),
        ),
        OutlinedButton.icon(
          key: const Key('institutionGroupRefreshButton'),
          onPressed: canChangeQuery ? onRefresh : null,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _GroupListBody extends StatelessWidget {
  const _GroupListBody({
    required this.state,
    required this.onSort,
    required this.onRetry,
    required this.onClearFilters,
    required this.onRefresh,
    required this.onPrevious,
    required this.onNext,
    required this.onFirstPage,
    required this.onPerPageChanged,
    required this.onCreate,
    required this.onOpenGroup,
  });

  final InstitutionGroupListState state;
  final ValueChanged<InstitutionGroupListSort> onSort;
  final VoidCallback onRetry;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFirstPage;
  final ValueChanged<int> onPerPageChanged;
  final VoidCallback onCreate;
  final ValueChanged<InstitutionGroup> onOpenGroup;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      InstitutionGroupListStatus.initial ||
      InstitutionGroupListStatus.loading => const _GroupListLoading(
        key: Key('institutionGroupListLoading'),
        label: 'Loading groups',
      ),
      InstitutionGroupListStatus.queryLoading => const _GroupListLoading(
        key: Key('institutionGroupListQueryLoading'),
        label: 'Loading matching groups',
      ),
      InstitutionGroupListStatus.refreshing => _GroupListData(
        state: state,
        isRefreshing: true,
        onSort: onSort,
        onPrevious: onPrevious,
        onNext: onNext,
        onPerPageChanged: onPerPageChanged,
        onOpenGroup: onOpenGroup,
      ),
      InstitutionGroupListStatus.error => _GroupListError(
        failure: state.failure!,
        isRetryInFlight: state.isRetryInFlight,
        onRetry: onRetry,
      ),
      InstitutionGroupListStatus.globalEmpty => _GroupListEmpty(
        key: const Key('institutionGroupListGlobalEmpty'),
        state: state,
        title: 'No groups available',
        message: 'No groups exist for this institution.',
        actions: [
          FilledButton.icon(
            key: const Key('institutionGroupGlobalEmptyCreateButton'),
            onPressed: onCreate,
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Create Group'),
          ),
        ],
        onPrevious: onPrevious,
        onNext: onNext,
        onPerPageChanged: onPerPageChanged,
      ),
      InstitutionGroupListStatus.filteredEmpty => _GroupListEmpty(
        key: const Key('institutionGroupListFilteredEmpty'),
        state: state,
        title: 'No matching groups',
        message: 'No groups match the current search or status.',
        actions: [
          OutlinedButton.icon(
            key: const Key('institutionGroupFilteredEmptyClearButton'),
            onPressed: onClearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Clear filters'),
          ),
        ],
        onPrevious: onPrevious,
        onNext: onNext,
        onPerPageChanged: onPerPageChanged,
      ),
      InstitutionGroupListStatus.emptyPage => _GroupListEmptyPage(
        state: state,
        onFirstPage: onFirstPage,
        onPrevious: onPrevious,
        onNext: onNext,
        onRefresh: onRefresh,
        onPerPageChanged: onPerPageChanged,
      ),
      InstitutionGroupListStatus.data => _GroupListData(
        state: state,
        isRefreshing: false,
        onSort: onSort,
        onPrevious: onPrevious,
        onNext: onNext,
        onPerPageChanged: onPerPageChanged,
        onOpenGroup: onOpenGroup,
      ),
    };
  }
}

class _GroupListLoading extends StatelessWidget {
  const _GroupListLoading({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Semantics(
          label: label,
          liveRegion: true,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _GroupListData extends StatelessWidget {
  const _GroupListData({
    required this.state,
    required this.isRefreshing,
    required this.onSort,
    required this.onPrevious,
    required this.onNext,
    required this.onPerPageChanged,
    required this.onOpenGroup,
  });

  final InstitutionGroupListState state;
  final bool isRefreshing;
  final ValueChanged<InstitutionGroupListSort> onSort;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onPerPageChanged;
  final ValueChanged<InstitutionGroup> onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final result = state.result!;

    return Column(
      key: const Key('institutionGroupListData'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isRefreshing) ...[
          const LinearProgressIndicator(
            key: Key('institutionGroupListRefreshing'),
            semanticsLabel: 'Refreshing groups',
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Sorted by ${_sortLabel(state.query.sort)}, '
          '${_directionLabel(state.query.direction)}',
          key: const Key('institutionGroupSortSummary'),
        ),
        const SizedBox(height: 12),
        _GroupTable(
          result: result,
          query: state.query,
          canSort: state.canChangeQuery,
          onSort: onSort,
          onOpenGroup: onOpenGroup,
        ),
        const SizedBox(height: _sectionSpacing),
        _GroupPagination(
          state: state,
          result: result,
          onPrevious: onPrevious,
          onNext: onNext,
          onPerPageChanged: onPerPageChanged,
        ),
      ],
    );
  }
}

class _GroupTable extends StatefulWidget {
  const _GroupTable({
    required this.result,
    required this.query,
    required this.canSort,
    required this.onSort,
    required this.onOpenGroup,
  });

  final InstitutionGroupListPage result;
  final InstitutionGroupListQuery query;
  final bool canSort;
  final ValueChanged<InstitutionGroupListSort> onSort;
  final ValueChanged<InstitutionGroup> onOpenGroup;

  @override
  State<_GroupTable> createState() => _GroupTableState();
}

class _GroupTableState extends State<_GroupTable> {
  late final ScrollController _horizontalScrollController;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _horizontalScrollController,
      child: SingleChildScrollView(
        key: const Key('institutionGroupHorizontalScroll'),
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: _tableMinWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(_panelRadius),
            ),
            child: DataTable(
              key: const Key('institutionGroupTable'),
              showCheckboxColumn: false,
              sortColumnIndex: _sortColumnIndex(widget.query.sort),
              sortAscending:
                  widget.query.direction == InstitutionGroupSortDirection.asc,
              columns: [
                _sortableColumn('Name', InstitutionGroupListSort.name),
                const DataColumn(label: Text('Level')),
                const DataColumn(label: Text('Subject direction')),
                _sortableColumn('Status', InstitutionGroupListSort.status),
                const DataColumn(label: Text('Teachers')),
                const DataColumn(label: Text('Students')),
                _sortableColumn('Created', InstitutionGroupListSort.createdAt),
                _sortableColumn('Updated', InstitutionGroupListSort.updatedAt),
              ],
              rows: [
                for (
                  var index = 0;
                  index < widget.result.groups.length;
                  index++
                )
                  _groupRow(widget.result.groups[index], index),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataColumn _sortableColumn(String label, InstitutionGroupListSort sort) {
    final selected = widget.query.sort == sort;
    final direction = selected
        ? _directionLabel(widget.query.direction)
        : 'ascending';

    return DataColumn(
      label: Semantics(
        label: widget.canSort
            ? selected
                  ? '$label, sorted $direction. Activate to change sorting.'
                  : '$label. Activate to sort ascending.'
            : '$label sorting is unavailable while groups are loading.',
        button: widget.canSort,
        enabled: widget.canSort,
        child: Text(label),
      ),
      tooltip: selected
          ? 'Sorted $direction; activate to change sorting'
          : 'Sort by $label ascending',
      onSort: widget.canSort ? (_, _) => widget.onSort(sort) : null,
    );
  }

  DataRow _groupRow(InstitutionGroup group, int index) {
    return DataRow(
      key: ValueKey('institutionGroupRow${group.id}'),
      onSelectChanged: (_) => widget.onOpenGroup(group),
      cells: [
        DataCell(
          _BoundedGroupText(
            value: group.name,
            key: Key('institutionGroupName$index'),
            semanticsLabel: 'Open group details for ${group.name}',
            onSemanticsTap: () => widget.onOpenGroup(group),
          ),
        ),
        DataCell(_BoundedGroupText(value: group.level ?? '—')),
        DataCell(_BoundedGroupText(value: group.subjectDirection ?? '—')),
        DataCell(_GroupStatus(status: group.status)),
        DataCell(Text(group.teachersCount.toString())),
        DataCell(Text(group.studentsCount.toString())),
        DataCell(Text(_formatUtc(group.createdAt))),
        DataCell(Text(_formatUtc(group.updatedAt))),
      ],
    );
  }

  int _sortColumnIndex(InstitutionGroupListSort sort) {
    return switch (sort) {
      InstitutionGroupListSort.name => 0,
      InstitutionGroupListSort.status => 3,
      InstitutionGroupListSort.createdAt => 6,
      InstitutionGroupListSort.updatedAt => 7,
    };
  }
}

class _BoundedGroupText extends StatelessWidget {
  const _BoundedGroupText({
    required this.value,
    super.key,
    this.semanticsLabel,
    this.onSemanticsTap,
  });

  final String value;
  final String? semanticsLabel;
  final VoidCallback? onSemanticsTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: value,
      child: Semantics(
        container: semanticsLabel != null,
        excludeSemantics: semanticsLabel != null,
        label: semanticsLabel ?? value,
        button: semanticsLabel != null,
        onTap: onSemanticsTap,
        child: SizedBox(
          width: 190,
          child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _GroupStatus extends StatelessWidget {
  const _GroupStatus({required this.status});

  final InstitutionGroupStatus status;

  @override
  Widget build(BuildContext context) {
    final isActive = status == InstitutionGroupStatus.active;
    final label = isActive ? 'Active' : 'Archived';
    final icon = isActive ? Icons.check_circle_outline : Icons.archive_outlined;
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;

    return Semantics(
      label: 'Group status: $label',
      child: Chip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(label),
      ),
    );
  }
}

class _GroupListEmpty extends StatelessWidget {
  const _GroupListEmpty({
    required this.state,
    required this.title,
    required this.message,
    required this.actions,
    required this.onPrevious,
    required this.onNext,
    required this.onPerPageChanged,
    super.key,
  });

  final InstitutionGroupListState state;
  final String title;
  final String message;
  final List<Widget> actions;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onPerPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EmptyPanel(title: title, message: message, actions: actions),
        const SizedBox(height: _sectionSpacing),
        _GroupPagination(
          state: state,
          result: state.result!,
          onPrevious: onPrevious,
          onNext: onNext,
          onPerPageChanged: onPerPageChanged,
        ),
      ],
    );
  }
}

class _GroupListEmptyPage extends StatelessWidget {
  const _GroupListEmptyPage({
    required this.state,
    required this.onFirstPage,
    required this.onPrevious,
    required this.onNext,
    required this.onRefresh,
    required this.onPerPageChanged,
  });

  final InstitutionGroupListState state;
  final VoidCallback onFirstPage;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onRefresh;
  final ValueChanged<int> onPerPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('institutionGroupListEmptyPage'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EmptyPanel(
          title: 'No groups on this page',
          message: 'The requested page is empty.',
          actions: [
            OutlinedButton.icon(
              key: const Key('institutionGroupFirstPageButton'),
              onPressed: state.canChangeQuery ? onFirstPage : null,
              icon: const Icon(Icons.first_page),
              label: const Text('Page 1'),
            ),
            OutlinedButton.icon(
              key: const Key('institutionGroupEmptyPreviousButton'),
              onPressed: state.canGoPrevious ? onPrevious : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
            OutlinedButton.icon(
              key: const Key('institutionGroupEmptyRefreshButton'),
              onPressed: state.canChangeQuery ? onRefresh : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: _sectionSpacing),
        _GroupPagination(
          state: state,
          result: state.result!,
          onPrevious: onPrevious,
          onNext: onNext,
          onPerPageChanged: onPerPageChanged,
        ),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(_panelRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: _controlSpacing,
                runSpacing: _controlSpacing,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupPagination extends StatelessWidget {
  const _GroupPagination({
    required this.state,
    required this.result,
    required this.onPrevious,
    required this.onNext,
    required this.onPerPageChanged,
  });

  final InstitutionGroupListState state;
  final InstitutionGroupListPage result;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onPerPageChanged;

  @override
  Widget build(BuildContext context) {
    final pagination = result.pagination;
    final range = result.groups.isEmpty
        ? '0-0 of ${pagination.total}'
        : '${result.rangeStart}-${result.rangeEnd} of ${pagination.total}';

    return Wrap(
      key: const Key('institutionGroupPagination'),
      spacing: _controlSpacing,
      runSpacing: _controlSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(range, key: const Key('institutionGroupRangeStatus')),
        Text(
          'Page ${pagination.page} of ${pagination.lastPage}',
          key: const Key('institutionGroupPageStatus'),
        ),
        OutlinedButton.icon(
          key: const Key('institutionGroupPreviousButton'),
          onPressed: state.canGoPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Previous'),
        ),
        OutlinedButton.icon(
          key: const Key('institutionGroupNextButton'),
          onPressed: state.canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
        SizedBox(
          width: 148,
          child: InputDecorator(
            key: const Key('institutionGroupPageSize'),
            decoration: const InputDecoration(
              labelText: 'Page size',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: state.query.perPage,
                isExpanded: true,
                items: [
                  for (final pageSize
                      in InstitutionGroupListQuery.pageSizeOptions)
                    DropdownMenuItem<int>(
                      value: pageSize,
                      child: Text(pageSize.toString()),
                    ),
                ],
                onChanged: state.canChangeQuery
                    ? (value) {
                        if (value != null) {
                          onPerPageChanged(value);
                        }
                      }
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupListError extends StatelessWidget {
  const _GroupListError({
    required this.failure,
    required this.isRetryInFlight,
    required this.onRetry,
  });

  final ApiFailure failure;
  final bool isRetryInFlight;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('institutionGroupListError'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load groups',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _groupListFailureMessage(failure),
                key: const Key('institutionGroupListErrorMessage'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('institutionGroupRetryButton'),
                onPressed: isRetryInFlight ? null : onRetry,
                icon: isRetryInFlight
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(isRetryInFlight ? 'Retrying' : 'Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _groupListFailureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.forbidden => 'You do not have permission to view groups.',
    ApiErrorCodes.validationFailed =>
      'The group list request did not match the API contract.',
    ApiErrorCodes.resourceNotFound => 'The groups list could not be loaded.',
    ApiErrorCodes.rateLimited => 'Too many requests. Wait before trying again.',
    _ => switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The group list request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected group list response.',
      ApiFailureKind.cancelled => 'The group list request was cancelled.',
      ApiFailureKind.unknown ||
      ApiFailureKind.server ||
      ApiFailureKind.validation => 'The groups list could not be loaded.',
    },
  };
}

String _statusFilterLabel(InstitutionGroupStatusFilter status) {
  return switch (status) {
    InstitutionGroupStatusFilter.active => 'Active',
    InstitutionGroupStatusFilter.archived => 'Archived',
  };
}

String _sortLabel(InstitutionGroupListSort sort) {
  return switch (sort) {
    InstitutionGroupListSort.name => 'Name',
    InstitutionGroupListSort.status => 'Status',
    InstitutionGroupListSort.createdAt => 'Created',
    InstitutionGroupListSort.updatedAt => 'Updated',
  };
}

String _directionLabel(InstitutionGroupSortDirection direction) {
  return switch (direction) {
    InstitutionGroupSortDirection.asc => 'ascending',
    InstitutionGroupSortDirection.desc => 'descending',
  };
}

String _formatUtc(DateTime value) {
  final utc = value.toUtc();

  return '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')} '
      '${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')} UTC';
}
