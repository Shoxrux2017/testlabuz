import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../application/institution_user_list_controller.dart';
import '../application/institution_user_list_state.dart';
import '../domain/institution_user.dart';
import '../domain/institution_user_list.dart';
import '../domain/institution_user_list_query.dart';
import 'institution_admin_user_formatters.dart';

const _pagePadding = 24.0;
const _sectionSpacing = 20.0;
const _controlSpacing = 12.0;
const _panelRadius = 8.0;
const _searchWidth = 320.0;
const _filterWidth = 180.0;
const _tableMinWidth = 1510.0;

class InstitutionAdminUsersScreen extends ConsumerStatefulWidget {
  const InstitutionAdminUsersScreen({super.key});

  @override
  ConsumerState<InstitutionAdminUsersScreen> createState() =>
      _InstitutionAdminUsersScreenState();
}

class _InstitutionAdminUsersScreenState
    extends ConsumerState<InstitutionAdminUsersScreen> {
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
    final state = ref.watch(institutionUserListControllerProvider);
    _syncSearchController(state.searchDraft);
    final controller = ref.read(institutionUserListControllerProvider.notifier);

    return SingleChildScrollView(
      key: const Key('institutionUserListSurface'),
      padding: const EdgeInsets.all(_pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            key: const Key('institutionUserListHeader'),
            spacing: _controlSpacing,
            runSpacing: _controlSpacing,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Users',
                key: const Key('institutionUserListHeading'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              FilledButton.icon(
                key: const Key('institutionUserCreateButton'),
                onPressed: () =>
                    context.goNamed(AppRouteNames.institutionAdminUserCreate),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Create User'),
              ),
            ],
          ),
          const SizedBox(height: _sectionSpacing),
          _UserListToolbar(
            state: state,
            searchController: _searchController,
            onSearchChanged: controller.updateSearchDraft,
            onSearchSubmitted: controller.commitSearchNow,
            onRoleChanged: controller.setRole,
            onStatusChanged: controller.setStatus,
            onClearFilters: controller.clearFilters,
            onRefresh: controller.refresh,
          ),
          const SizedBox(height: _sectionSpacing),
          _UserListBody(
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
                context.goNamed(AppRouteNames.institutionAdminUserCreate),
            onOpenUser: (user) => context.goNamed(
              AppRouteNames.institutionAdminUserDetail,
              pathParameters: {
                AppRoutePaths.institutionAdminUserIdParameter: user.id,
              },
            ),
          ),
        ],
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

class _UserListToolbar extends StatelessWidget {
  const _UserListToolbar({
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onClearFilters,
    required this.onRefresh,
  });

  final InstitutionUserListState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<InstitutionUserRole?> onRoleChanged;
  final ValueChanged<InstitutionUserStatusFilter?> onStatusChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final canChangeQuery = state.canChangeQuery;
    final canClear = state.canClearFilters && !state.isRequestInFlight;

    return Wrap(
      key: const Key('institutionUserListToolbar'),
      spacing: _controlSpacing,
      runSpacing: _controlSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: _searchWidth,
          child: TextField(
            key: const Key('institutionUserSearchField'),
            controller: searchController,
            enabled: !state.isRequestInFlight,
            decoration: InputDecoration(
              labelText: 'Search users',
              errorText: state.searchErrorText,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            maxLength: InstitutionUserListQuery.maxSearchLength,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            textInputAction: TextInputAction.search,
            onChanged: onSearchChanged,
            onSubmitted: (_) => onSearchSubmitted(),
          ),
        ),
        _NullableFilter<InstitutionUserRole>(
          key: const Key('institutionUserRoleFilter'),
          label: 'Role',
          value: state.query.role,
          allLabel: 'All roles',
          options: InstitutionUserRole.values,
          optionLabel: formatInstitutionUserRole,
          onChanged: canChangeQuery ? onRoleChanged : null,
        ),
        _NullableFilter<InstitutionUserStatusFilter>(
          key: const Key('institutionUserStatusFilter'),
          label: 'Status',
          value: state.query.status,
          allLabel: 'All statuses',
          options: InstitutionUserStatusFilter.values,
          optionLabel: _statusFilterLabel,
          onChanged: canChangeQuery ? onStatusChanged : null,
        ),
        OutlinedButton.icon(
          key: const Key('institutionUserClearFiltersButton'),
          onPressed: canClear ? onClearFilters : null,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Clear filters'),
        ),
        OutlinedButton.icon(
          key: const Key('institutionUserRefreshButton'),
          onPressed: canChangeQuery ? onRefresh : null,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _NullableFilter<T> extends StatelessWidget {
  const _NullableFilter({
    required super.key,
    required this.label,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final String allLabel;
  final List<T> options;
  final String Function(T value) optionLabel;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _filterWidth,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T?>(
            value: value,
            isExpanded: true,
            items: [
              DropdownMenuItem<T?>(value: null, child: Text(allLabel)),
              for (final option in options)
                DropdownMenuItem<T?>(
                  value: option,
                  child: Text(optionLabel(option)),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _UserListBody extends StatelessWidget {
  const _UserListBody({
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
    required this.onOpenUser,
  });

  final InstitutionUserListState state;
  final ValueChanged<InstitutionUserListSort> onSort;
  final VoidCallback onRetry;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFirstPage;
  final ValueChanged<int> onPerPageChanged;
  final VoidCallback onCreate;
  final ValueChanged<InstitutionUser> onOpenUser;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      InstitutionUserListStatus.initial ||
      InstitutionUserListStatus.loading => const _UserListLoading(
        key: Key('institutionUserListLoading'),
        label: 'Loading users',
      ),
      InstitutionUserListStatus.queryLoading => const _UserListLoading(
        key: Key('institutionUserListQueryLoading'),
        label: 'Loading matching users',
      ),
      InstitutionUserListStatus.refreshing => _UserListData(
        state: state,
        isRefreshing: true,
        onSort: onSort,
        onPrevious: onPrevious,
        onNext: onNext,
        onPerPageChanged: onPerPageChanged,
        onOpenUser: onOpenUser,
      ),
      InstitutionUserListStatus.error => _UserListError(
        failure: state.failure!,
        isRetryInFlight: state.isRetryInFlight,
        onRetry: onRetry,
      ),
      InstitutionUserListStatus.globalEmpty => _UserListEmpty(
        key: const Key('institutionUserListGlobalEmpty'),
        state: state,
        title: 'No users available',
        message: 'No Teachers, Students, or Parents exist yet.',
        action: FilledButton.icon(
          key: const Key('institutionUserGlobalEmptyCreateButton'),
          onPressed: onCreate,
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Create User'),
        ),
        onPrevious: onPrevious,
        onNext: onNext,
        onPerPageChanged: onPerPageChanged,
      ),
      InstitutionUserListStatus.filteredEmpty => _UserListEmpty(
        key: const Key('institutionUserListFilteredEmpty'),
        state: state,
        title: 'No matching users',
        message: 'No users match the current search or filters.',
        action: OutlinedButton.icon(
          key: const Key('institutionUserFilteredEmptyClearButton'),
          onPressed: onClearFilters,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Clear filters'),
        ),
        onPrevious: onPrevious,
        onNext: onNext,
        onPerPageChanged: onPerPageChanged,
      ),
      InstitutionUserListStatus.emptyPage => _UserListEmptyPage(
        state: state,
        onFirstPage: onFirstPage,
        onPrevious: onPrevious,
        onNext: onNext,
        onRefresh: onRefresh,
        onPerPageChanged: onPerPageChanged,
      ),
      InstitutionUserListStatus.data => _UserListData(
        state: state,
        isRefreshing: false,
        onSort: onSort,
        onPrevious: onPrevious,
        onNext: onNext,
        onPerPageChanged: onPerPageChanged,
        onOpenUser: onOpenUser,
      ),
    };
  }
}

class _UserListLoading extends StatelessWidget {
  const _UserListLoading({required this.label, super.key});

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

class _UserListData extends StatelessWidget {
  const _UserListData({
    required this.state,
    required this.isRefreshing,
    required this.onSort,
    required this.onPrevious,
    required this.onNext,
    required this.onPerPageChanged,
    required this.onOpenUser,
  });

  final InstitutionUserListState state;
  final bool isRefreshing;
  final ValueChanged<InstitutionUserListSort> onSort;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onPerPageChanged;
  final ValueChanged<InstitutionUser> onOpenUser;

  @override
  Widget build(BuildContext context) {
    final result = state.result!;

    return Column(
      key: const Key('institutionUserListData'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isRefreshing) ...[
          const LinearProgressIndicator(
            key: Key('institutionUserListRefreshing'),
            semanticsLabel: 'Refreshing users',
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Sorted by ${_sortLabel(state.query.sort)}, '
          '${_directionLabel(state.query.direction)}',
          key: const Key('institutionUserSortSummary'),
        ),
        const SizedBox(height: 12),
        _UserTable(
          result: result,
          query: state.query,
          canSort: state.canChangeQuery,
          onSort: onSort,
          onOpenUser: onOpenUser,
        ),
        const SizedBox(height: _sectionSpacing),
        _UserPagination(
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

class _UserTable extends StatelessWidget {
  const _UserTable({
    required this.result,
    required this.query,
    required this.canSort,
    required this.onSort,
    required this.onOpenUser,
  });

  final InstitutionUserListPage result;
  final InstitutionUserListQuery query;
  final bool canSort;
  final ValueChanged<InstitutionUserListSort> onSort;
  final ValueChanged<InstitutionUser> onOpenUser;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        key: const Key('institutionUserHorizontalScroll'),
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: _tableMinWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(_panelRadius),
            ),
            child: DataTable(
              key: const Key('institutionUserTable'),
              showCheckboxColumn: false,
              sortColumnIndex: _sortColumnIndex(query.sort),
              sortAscending:
                  query.direction == InstitutionUserSortDirection.asc,
              columns: [
                _sortableColumn('Full name', InstitutionUserListSort.fullName),
                _sortableColumn(
                  'Login name',
                  InstitutionUserListSort.loginName,
                ),
                const DataColumn(label: Text('Role')),
                const DataColumn(label: Text('Contact')),
                const DataColumn(label: Text('Status')),
                const DataColumn(label: Text('First login')),
                _sortableColumn('Created', InstitutionUserListSort.createdAt),
                _sortableColumn('Updated', InstitutionUserListSort.updatedAt),
              ],
              rows: [
                for (var index = 0; index < result.users.length; index++)
                  _userRow(result.users[index], index),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataColumn _sortableColumn(String label, InstitutionUserListSort sort) {
    final selected = query.sort == sort;
    final direction = selected ? _directionLabel(query.direction) : 'ascending';

    return DataColumn(
      label: Semantics(
        label: canSort
            ? selected
                  ? '$label, sorted $direction. Activate to change sorting.'
                  : '$label. Activate to sort ascending.'
            : '$label sorting is unavailable while users are loading.',
        button: canSort,
        enabled: canSort,
        child: Text(label),
      ),
      tooltip: selected
          ? 'Sorted $direction; activate to change sorting'
          : 'Sort by $label ascending',
      onSort: canSort ? (_, _) => onSort(sort) : null,
    );
  }

  DataRow _userRow(InstitutionUser user, int index) {
    final role = formatInstitutionUserRole(user.role);

    return DataRow(
      key: ValueKey('institutionUserRow${user.id}'),
      onSelectChanged: (_) => onOpenUser(user),
      cells: [
        DataCell(
          _BoundedUserText(
            value: user.fullName,
            key: Key('institutionUserFullName$index'),
            semanticsLabel: 'Open user details for ${user.fullName}',
            onSemanticsTap: () => onOpenUser(user),
          ),
        ),
        DataCell(
          _BoundedUserText(
            value: user.loginName,
            key: Key('institutionUserLoginName$index'),
          ),
        ),
        DataCell(Text(role)),
        DataCell(_UserContact(user: user)),
        DataCell(_UserStatus(isActive: user.isActive)),
        DataCell(
          Text(
            user.mustChangePassword ? 'Password change required' : 'Completed',
          ),
        ),
        DataCell(Text(formatInstitutionUserUtc(user.createdAt))),
        DataCell(Text(formatInstitutionUserUtc(user.updatedAt))),
      ],
    );
  }

  int _sortColumnIndex(InstitutionUserListSort sort) {
    return switch (sort) {
      InstitutionUserListSort.fullName => 0,
      InstitutionUserListSort.loginName => 1,
      InstitutionUserListSort.createdAt => 6,
      InstitutionUserListSort.updatedAt => 7,
    };
  }
}

class _BoundedUserText extends StatelessWidget {
  const _BoundedUserText({
    required this.value,
    required super.key,
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
        label: semanticsLabel ?? value,
        button: semanticsLabel != null,
        onTap: onSemanticsTap,
        child: SizedBox(
          width: 200,
          child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _UserContact extends StatelessWidget {
  const _UserContact({required this.user});

  final InstitutionUser user;

  @override
  Widget build(BuildContext context) {
    if (user.email == null && user.phone == null) {
      return const Text('Not provided');
    }

    final values = <String>[?user.email, ?user.phone];

    return Semantics(
      label: values.join(', '),
      child: SizedBox(
        width: 230,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final value in values)
              Tooltip(
                message: value,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserStatus extends StatelessWidget {
  const _UserStatus({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final label = isActive ? 'Active' : 'Inactive';
    final icon = isActive ? Icons.check_circle_outline : Icons.block;
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    return Semantics(
      label: 'User status: $label',
      child: Chip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(label),
      ),
    );
  }
}

class _UserListEmpty extends StatelessWidget {
  const _UserListEmpty({
    required this.state,
    required this.title,
    required this.message,
    required this.action,
    required this.onPrevious,
    required this.onNext,
    required this.onPerPageChanged,
    super.key,
  });

  final InstitutionUserListState state;
  final String title;
  final String message;
  final Widget action;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onPerPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EmptyPanel(title: title, message: message, actions: [action]),
        const SizedBox(height: _sectionSpacing),
        _UserPagination(
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

class _UserListEmptyPage extends StatelessWidget {
  const _UserListEmptyPage({
    required this.state,
    required this.onFirstPage,
    required this.onPrevious,
    required this.onNext,
    required this.onRefresh,
    required this.onPerPageChanged,
  });

  final InstitutionUserListState state;
  final VoidCallback onFirstPage;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onRefresh;
  final ValueChanged<int> onPerPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('institutionUserListEmptyPage'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EmptyPanel(
          title: 'No users on this page',
          message: 'The requested page is empty.',
          actions: [
            OutlinedButton.icon(
              key: const Key('institutionUserFirstPageButton'),
              onPressed: onFirstPage,
              icon: const Icon(Icons.first_page),
              label: const Text('Page 1'),
            ),
            OutlinedButton.icon(
              key: const Key('institutionUserEmptyPreviousButton'),
              onPressed: state.canGoPrevious ? onPrevious : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
            OutlinedButton.icon(
              key: const Key('institutionUserEmptyRefreshButton'),
              onPressed: state.canChangeQuery ? onRefresh : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: _sectionSpacing),
        _UserPagination(
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
            const SizedBox(height: 16),
            Wrap(
              spacing: _controlSpacing,
              runSpacing: _controlSpacing,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserPagination extends StatelessWidget {
  const _UserPagination({
    required this.state,
    required this.result,
    required this.onPrevious,
    required this.onNext,
    required this.onPerPageChanged,
  });

  final InstitutionUserListState state;
  final InstitutionUserListPage result;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onPerPageChanged;

  @override
  Widget build(BuildContext context) {
    final pagination = result.pagination;
    final range = result.users.isEmpty
        ? '0-0 of ${pagination.total}'
        : '${result.rangeStart}-${result.rangeEnd} of ${pagination.total}';

    return Wrap(
      key: const Key('institutionUserPagination'),
      spacing: _controlSpacing,
      runSpacing: _controlSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(range, key: const Key('institutionUserRangeStatus')),
        Text(
          'Page ${pagination.page} of ${pagination.lastPage}',
          key: const Key('institutionUserPageStatus'),
        ),
        OutlinedButton.icon(
          key: const Key('institutionUserPreviousButton'),
          onPressed: state.canGoPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Previous'),
        ),
        OutlinedButton.icon(
          key: const Key('institutionUserNextButton'),
          onPressed: state.canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
        SizedBox(
          width: 148,
          child: InputDecorator(
            key: const Key('institutionUserPageSize'),
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
                      in InstitutionUserListQuery.pageSizeOptions)
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

class _UserListError extends StatelessWidget {
  const _UserListError({
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
      key: const Key('institutionUserListError'),
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
                'Users unavailable',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _userListFailureMessage(failure),
                key: const Key('institutionUserListErrorMessage'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('institutionUserRetryButton'),
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

String _userListFailureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.authenticationRequired => 'Please sign in again.',
    ApiErrorCodes.passwordChangeRequired =>
      'Password change is required before institution access.',
    ApiErrorCodes.userInactive => 'This account is inactive.',
    ApiErrorCodes.institutionInactive => 'This institution is inactive.',
    ApiErrorCodes.forbidden => 'You do not have permission to view users.',
    ApiErrorCodes.validationFailed =>
      'The user list request did not match the API contract.',
    _ => switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The user list request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected user list response.',
      ApiFailureKind.cancelled => 'The user list request was cancelled.',
      ApiFailureKind.unknown ||
      ApiFailureKind.server ||
      ApiFailureKind.validation => 'The users list could not be loaded.',
    },
  };
}

String _statusFilterLabel(InstitutionUserStatusFilter status) {
  return switch (status) {
    InstitutionUserStatusFilter.active => 'Active',
    InstitutionUserStatusFilter.inactive => 'Inactive',
  };
}

String _sortLabel(InstitutionUserListSort sort) {
  return switch (sort) {
    InstitutionUserListSort.fullName => 'Full name',
    InstitutionUserListSort.loginName => 'Login name',
    InstitutionUserListSort.createdAt => 'Created',
    InstitutionUserListSort.updatedAt => 'Updated',
  };
}

String _directionLabel(InstitutionUserSortDirection direction) {
  return switch (direction) {
    InstitutionUserSortDirection.asc => 'ascending',
    InstitutionUserSortDirection.desc => 'descending',
  };
}
