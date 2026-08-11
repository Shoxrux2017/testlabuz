import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../application/platform_institution_list_controller.dart';
import '../application/platform_institution_list_state.dart';
import '../domain/platform_institution.dart';
import '../domain/platform_institution_list.dart';
import '../domain/platform_institution_list_query.dart';
import 'platform_dashboard_formatters.dart';

const _pageSpacing = 24.0;
const _sectionSpacing = 20.0;
const _controlSpacing = 12.0;
const _tableRadius = 8.0;
const _searchWidth = 320.0;
const _statusWidth = 180.0;
const _typeWidth = 220.0;
const _tableMinWidth = 1210.0;

class PlatformOwnerInstitutionsScreen extends ConsumerStatefulWidget {
  const PlatformOwnerInstitutionsScreen({super.key});

  @override
  ConsumerState<PlatformOwnerInstitutionsScreen> createState() {
    return _PlatformOwnerInstitutionsScreenState();
  }
}

class _PlatformOwnerInstitutionsScreenState
    extends ConsumerState<PlatformOwnerInstitutionsScreen> {
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
    final state = ref.watch(platformInstitutionListControllerProvider);
    _syncSearchController(state.searchText);

    return SingleChildScrollView(
      key: const Key('platformInstitutionListSurface'),
      padding: const EdgeInsets.all(_pageSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Institutions',
            key: const Key('platformInstitutionListHeading'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: _sectionSpacing),
          _InstitutionListToolbar(
            state: state,
            searchController: _searchController,
            onSearchChanged: (value) {
              ref
                  .read(platformInstitutionListControllerProvider.notifier)
                  .updateSearchText(value);
            },
            onSearchSubmitted: () {
              ref
                  .read(platformInstitutionListControllerProvider.notifier)
                  .commitSearchNow();
            },
            onStatusChanged: (status) {
              ref
                  .read(platformInstitutionListControllerProvider.notifier)
                  .setStatus(status);
            },
            onTypeChanged: (type) {
              ref
                  .read(platformInstitutionListControllerProvider.notifier)
                  .setType(type);
            },
            onReset: () {
              ref
                  .read(platformInstitutionListControllerProvider.notifier)
                  .reset();
            },
          ),
          const SizedBox(height: _sectionSpacing),
          _InstitutionListBody(
            state: state,
            onSort: (sort) {
              ref
                  .read(platformInstitutionListControllerProvider.notifier)
                  .toggleSort(sort);
            },
            onRetry: () {
              ref
                  .read(platformInstitutionListControllerProvider.notifier)
                  .retry();
            },
            onReset: () {
              ref
                  .read(platformInstitutionListControllerProvider.notifier)
                  .reset();
            },
            onPrevious: () {
              ref
                  .read(platformInstitutionListControllerProvider.notifier)
                  .previousPage();
            },
            onNext: () {
              ref
                  .read(platformInstitutionListControllerProvider.notifier)
                  .nextPage();
            },
            onFirstPage: () {
              ref
                  .read(platformInstitutionListControllerProvider.notifier)
                  .returnToFirstPage();
            },
            onPerPageChanged: (perPage) {
              ref
                  .read(platformInstitutionListControllerProvider.notifier)
                  .setPerPage(perPage);
            },
            onViewDetails: (institution) {
              context.goNamed(
                AppRouteNames.platformOwnerInstitutionDetail,
                pathParameters: {
                  AppRoutePaths.platformOwnerInstitutionIdParameter:
                      institution.id,
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _syncSearchController(String text) {
    if (_searchController.text == text) {
      return;
    }

    _searchController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _InstitutionListToolbar extends StatelessWidget {
  const _InstitutionListToolbar({
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onStatusChanged,
    required this.onTypeChanged,
    required this.onReset,
  });

  final PlatformInstitutionListState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<PlatformInstitutionStatus?> onStatusChanged;
  final ValueChanged<PlatformInstitutionType?> onTypeChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('platformInstitutionListToolbar'),
      spacing: _controlSpacing,
      runSpacing: _controlSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: _searchWidth,
          child: TextField(
            key: const Key('platformInstitutionSearchField'),
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Search institutions',
              hintText: 'Institution name',
              errorText: state.searchErrorText,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            maxLength: PlatformInstitutionListQuery.maxSearchLength,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            textInputAction: TextInputAction.search,
            onChanged: onSearchChanged,
            onSubmitted: (_) => onSearchSubmitted(),
          ),
        ),
        SizedBox(
          width: _statusWidth,
          child: InputDecorator(
            key: const Key('platformInstitutionStatusFilter'),
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PlatformInstitutionStatus?>(
                value: state.query.status,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<PlatformInstitutionStatus?>(
                    value: null,
                    child: Text('All statuses'),
                  ),
                  for (final status in PlatformInstitutionStatus.values)
                    DropdownMenuItem<PlatformInstitutionStatus?>(
                      value: status,
                      child: Text(platformInstitutionStatusLabel(status)),
                    ),
                ],
                onChanged: onStatusChanged,
              ),
            ),
          ),
        ),
        SizedBox(
          width: _typeWidth,
          child: InputDecorator(
            key: const Key('platformInstitutionTypeFilter'),
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PlatformInstitutionType?>(
                value: state.query.type,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<PlatformInstitutionType?>(
                    value: null,
                    child: Text('All types'),
                  ),
                  for (final type in PlatformInstitutionType.values)
                    DropdownMenuItem<PlatformInstitutionType?>(
                      value: type,
                      child: Text(platformInstitutionTypeLabel(type)),
                    ),
                ],
                onChanged: onTypeChanged,
              ),
            ),
          ),
        ),
        OutlinedButton.icon(
          key: const Key('platformInstitutionResetButton'),
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset'),
        ),
      ],
    );
  }
}

class _InstitutionListBody extends StatelessWidget {
  const _InstitutionListBody({
    required this.state,
    required this.onSort,
    required this.onRetry,
    required this.onReset,
    required this.onPrevious,
    required this.onNext,
    required this.onFirstPage,
    required this.onPerPageChanged,
    required this.onViewDetails,
  });

  final PlatformInstitutionListState state;
  final ValueChanged<PlatformInstitutionListSort> onSort;
  final VoidCallback onRetry;
  final VoidCallback onReset;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFirstPage;
  final ValueChanged<int> onPerPageChanged;
  final ValueChanged<PlatformInstitutionSummary> onViewDetails;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      PlatformInstitutionListStatus.initial ||
      PlatformInstitutionListStatus.loading => const _InstitutionListLoading(
        key: Key('platformInstitutionListLoading'),
        label: 'Loading institutions',
      ),
      PlatformInstitutionListStatus.queryLoading =>
        const _InstitutionListLoading(
          key: Key('platformInstitutionListQueryLoading'),
          label: 'Loading matching institutions',
        ),
      PlatformInstitutionListStatus.error => _InstitutionListError(
        failure: state.failure!,
        isRetryInFlight: state.isRetryInFlight,
        onRetry: onRetry,
      ),
      PlatformInstitutionListStatus.globalEmpty => _InstitutionListEmptyState(
        key: const Key('platformInstitutionListGlobalEmpty'),
        title: 'No institutions available',
        message: 'No platform institutions exist yet.',
        result: state.result!,
        state: state,
        onPrevious: onPrevious,
        onNext: onNext,
        onPerPageChanged: onPerPageChanged,
      ),
      PlatformInstitutionListStatus.filteredEmpty => _InstitutionListEmptyState(
        key: const Key('platformInstitutionListFilteredEmpty'),
        title: 'No matching institutions',
        message: 'No institutions match the current search or filters.',
        result: state.result!,
        state: state,
        onPrevious: onPrevious,
        onNext: onNext,
        onPerPageChanged: onPerPageChanged,
        trailing: OutlinedButton.icon(
          key: const Key('platformInstitutionFilteredResetButton'),
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset'),
        ),
      ),
      PlatformInstitutionListStatus.emptyPage => _InstitutionListEmptyPage(
        result: state.result!,
        state: state,
        onPrevious: onPrevious,
        onNext: onNext,
        onFirstPage: onFirstPage,
        onPerPageChanged: onPerPageChanged,
      ),
      PlatformInstitutionListStatus.data => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CurrentSortSummary(query: state.query),
          const SizedBox(height: 12),
          _InstitutionTable(
            result: state.result!,
            query: state.query,
            onSort: onSort,
            onViewDetails: onViewDetails,
          ),
          const SizedBox(height: _sectionSpacing),
          _PaginationControls(
            state: state,
            result: state.result!,
            onPrevious: onPrevious,
            onNext: onNext,
            onPerPageChanged: onPerPageChanged,
          ),
        ],
      ),
    };
  }
}

class _InstitutionListLoading extends StatelessWidget {
  const _InstitutionListLoading({super.key, required this.label});

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

class _InstitutionListEmptyState extends StatelessWidget {
  const _InstitutionListEmptyState({
    required this.title,
    required this.message,
    required this.result,
    required this.state,
    required this.onPrevious,
    required this.onNext,
    required this.onPerPageChanged,
    this.trailing,
    super.key,
  });

  final String title;
  final String message;
  final PlatformInstitutionListPage result;
  final PlatformInstitutionListState state;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onPerPageChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EmptyPanel(title: title, message: message, trailing: trailing),
        const SizedBox(height: _sectionSpacing),
        _PaginationControls(
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

class _InstitutionListEmptyPage extends StatelessWidget {
  const _InstitutionListEmptyPage({
    required this.result,
    required this.state,
    required this.onPrevious,
    required this.onNext,
    required this.onFirstPage,
    required this.onPerPageChanged,
  });

  final PlatformInstitutionListPage result;
  final PlatformInstitutionListState state;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFirstPage;
  final ValueChanged<int> onPerPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('platformInstitutionListEmptyPage'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EmptyPanel(
          title: 'No institutions on this page',
          message: 'The requested page is empty.',
          trailing: Wrap(
            spacing: _controlSpacing,
            runSpacing: _controlSpacing,
            children: [
              OutlinedButton.icon(
                key: const Key('platformInstitutionFirstPageButton'),
                onPressed: onFirstPage,
                icon: const Icon(Icons.first_page),
                label: const Text('Page 1'),
              ),
              OutlinedButton.icon(
                key: const Key('platformInstitutionEmptyPreviousButton'),
                onPressed: state.canGoPrevious ? onPrevious : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous'),
              ),
            ],
          ),
        ),
        const SizedBox(height: _sectionSpacing),
        _PaginationControls(
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

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.title,
    required this.message,
    this.trailing,
  });

  final String title;
  final String message;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(_tableRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_pageSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message),
            if (trailing != null) ...[const SizedBox(height: 16), trailing!],
          ],
        ),
      ),
    );
  }
}

class _CurrentSortSummary extends StatelessWidget {
  const _CurrentSortSummary({required this.query});

  final PlatformInstitutionListQuery query;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Sorted by ${_sortLabel(query.sort)}, ${_directionLabel(query.direction)}',
      key: const Key('platformInstitutionSortSummary'),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _InstitutionTable extends StatelessWidget {
  const _InstitutionTable({
    required this.result,
    required this.query,
    required this.onSort,
    required this.onViewDetails,
  });

  final PlatformInstitutionListPage result;
  final PlatformInstitutionListQuery query;
  final ValueChanged<PlatformInstitutionListSort> onSort;
  final ValueChanged<PlatformInstitutionSummary> onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        key: const Key('platformInstitutionHorizontalScroll'),
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: _tableMinWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(_tableRadius),
            ),
            child: DataTable(
              key: const Key('platformInstitutionTable'),
              sortColumnIndex: _sortColumnIndex(query.sort),
              sortAscending: query.direction == PlatformSortDirection.asc,
              columns: [
                _sortableColumn(
                  label: 'Institution',
                  sort: PlatformInstitutionListSort.name,
                  onSort: onSort,
                ),
                const DataColumn(label: Text('Type')),
                _sortableColumn(
                  label: 'Status',
                  sort: PlatformInstitutionListSort.status,
                  onSort: onSort,
                ),
                const DataColumn(label: Text('Users')),
                const DataColumn(label: Text('Contact')),
                _sortableColumn(
                  label: 'Created',
                  sort: PlatformInstitutionListSort.createdAt,
                  onSort: onSort,
                ),
                _sortableColumn(
                  label: 'Updated',
                  sort: PlatformInstitutionListSort.updatedAt,
                  onSort: onSort,
                ),
                const DataColumn(label: Text('Details')),
              ],
              rows: [
                for (var index = 0; index < result.institutions.length; index++)
                  _institutionRow(context, result.institutions[index], index),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataColumn _sortableColumn({
    required String label,
    required PlatformInstitutionListSort sort,
    required ValueChanged<PlatformInstitutionListSort> onSort,
  }) {
    return DataColumn(
      label: Text(label),
      tooltip: 'Sort by $label',
      onSort: (_, _) => onSort(sort),
    );
  }

  DataRow _institutionRow(
    BuildContext context,
    PlatformInstitutionSummary institution,
    int index,
  ) {
    return DataRow(
      key: ValueKey('platformInstitutionRow$index'),
      cells: [
        DataCell(_BoundedText(institution.name, keyName: 'Name$index')),
        DataCell(Text(platformInstitutionTypeLabel(institution.type))),
        DataCell(_InstitutionStatusBadge(status: institution.status)),
        DataCell(
          Semantics(
            label:
                '${institution.userCounts.active} active users of '
                '${institution.userCounts.total} total users',
            child: Text(
              '${institution.userCounts.active} active / '
              '${institution.userCounts.total} total',
              key: Key('platformInstitutionUsers$index'),
            ),
          ),
        ),
        DataCell(_InstitutionContactCell(institution: institution)),
        DataCell(
          Text(formatPlatformDashboardUtcTimestamp(institution.createdAt)),
        ),
        DataCell(
          Text(formatPlatformDashboardUtcTimestamp(institution.updatedAt)),
        ),
        DataCell(
          Semantics(
            button: true,
            label: 'View details for ${institution.name}',
            child: TextButton.icon(
              key: Key('platformInstitutionViewDetails$index'),
              onPressed: () => onViewDetails(institution),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('View details'),
            ),
          ),
        ),
      ],
    );
  }

  int _sortColumnIndex(PlatformInstitutionListSort sort) {
    return switch (sort) {
      PlatformInstitutionListSort.name => 0,
      PlatformInstitutionListSort.status => 2,
      PlatformInstitutionListSort.createdAt => 5,
      PlatformInstitutionListSort.updatedAt => 6,
    };
  }
}

class _BoundedText extends StatelessWidget {
  const _BoundedText(this.value, {required this.keyName});

  final String value;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: value,
      child: SizedBox(
        width: 220,
        child: Text(
          value,
          key: Key('platformInstitution$keyName'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _InstitutionContactCell extends StatelessWidget {
  const _InstitutionContactCell({required this.institution});

  final PlatformInstitutionSummary institution;

  @override
  Widget build(BuildContext context) {
    final email = institution.contactEmail;
    final phone = institution.contactPhone;

    if (email == null && phone == null) {
      return const Text('Not provided');
    }

    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (email != null)
            Tooltip(
              message: email,
              child: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          if (phone != null)
            Tooltip(
              message: phone,
              child: Text(phone, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}

class _InstitutionStatusBadge extends StatelessWidget {
  const _InstitutionStatusBadge({required this.status});

  final PlatformInstitutionStatus status;

  @override
  Widget build(BuildContext context) {
    final label = platformInstitutionStatusLabel(status);
    final color = switch (status) {
      PlatformInstitutionStatus.active => Theme.of(context).colorScheme.primary,
      PlatformInstitutionStatus.inactive => Theme.of(context).colorScheme.error,
    };

    return Semantics(
      label: 'Institution status: $label',
      child: Chip(
        avatar: Icon(Icons.circle, size: 10, color: color),
        label: Text(label),
      ),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.state,
    required this.result,
    required this.onPrevious,
    required this.onNext,
    required this.onPerPageChanged,
  });

  final PlatformInstitutionListState state;
  final PlatformInstitutionListPage result;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onPerPageChanged;

  @override
  Widget build(BuildContext context) {
    final pagination = result.pagination;

    return Wrap(
      key: const Key('platformInstitutionPagination'),
      spacing: _controlSpacing,
      runSpacing: _controlSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Page ${pagination.page} / ${pagination.lastPage}',
          key: const Key('platformInstitutionPageStatus'),
        ),
        Text(
          '${pagination.total} matching Institutions',
          key: const Key('platformInstitutionTotalStatus'),
        ),
        OutlinedButton.icon(
          key: const Key('platformInstitutionPreviousButton'),
          onPressed: state.canGoPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Previous'),
        ),
        OutlinedButton.icon(
          key: const Key('platformInstitutionNextButton'),
          onPressed: state.canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
        SizedBox(
          width: 148,
          child: InputDecorator(
            key: const Key('platformInstitutionPageSize'),
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
                      in PlatformInstitutionListQuery.pageSizeOptions)
                    DropdownMenuItem<int>(
                      value: pageSize,
                      child: Text(pageSize.toString()),
                    ),
                ],
                onChanged: state.isRequestInFlight
                    ? null
                    : (value) {
                        if (value != null) {
                          onPerPageChanged(value);
                        }
                      },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InstitutionListError extends StatelessWidget {
  const _InstitutionListError({
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
      key: const Key('platformInstitutionListError'),
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
                'Institutions unavailable',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _institutionListFailureMessage(failure),
                key: const Key('platformInstitutionListErrorMessage'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('platformInstitutionRetryButton'),
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

String _institutionListFailureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.authenticationRequired => 'Please sign in again.',
    ApiErrorCodes.passwordChangeRequired =>
      'Password change is required before institution access.',
    ApiErrorCodes.userInactive => 'This account is inactive.',
    ApiErrorCodes.institutionInactive => 'This institution is inactive.',
    ApiErrorCodes.forbidden =>
      'You do not have permission to view institutions.',
    ApiErrorCodes.validationFailed =>
      'The institution list request did not match the API contract.',
    _ => switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The institution list request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected institution list response.',
      ApiFailureKind.cancelled => 'The institution list request was cancelled.',
      ApiFailureKind.unknown ||
      ApiFailureKind.server ||
      ApiFailureKind.validation => 'The institutions list could not be loaded.',
    },
  };
}

String _sortLabel(PlatformInstitutionListSort sort) {
  return switch (sort) {
    PlatformInstitutionListSort.name => 'Institution',
    PlatformInstitutionListSort.createdAt => 'Created',
    PlatformInstitutionListSort.updatedAt => 'Updated',
    PlatformInstitutionListSort.status => 'Status',
  };
}

String _directionLabel(PlatformSortDirection direction) {
  return switch (direction) {
    PlatformSortDirection.asc => 'ascending',
    PlatformSortDirection.desc => 'descending',
  };
}
