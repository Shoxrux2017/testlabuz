import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../application/institution_parent_student_relationship_action_controller.dart';
import '../application/institution_parent_student_relationship_action_state.dart';
import '../application/institution_parent_student_relationship_list_controller.dart';
import '../application/institution_parent_student_relationship_list_state.dart';
import '../application/institution_user_selection_controller.dart';
import '../application/institution_user_selection_state.dart';
import '../domain/institution_parent_student_relationship.dart';
import '../domain/institution_parent_student_relationship_list.dart';
import '../domain/institution_parent_student_relationship_query.dart';
import '../domain/institution_user.dart';
import '../domain/institution_user_selection.dart';
import 'institution_admin_user_formatters.dart';

const _pagePadding = 24.0;
const _sectionSpacing = 20.0;
const _controlSpacing = 12.0;
const _panelRadius = 8.0;
const _tableMinWidth = 1020.0;

class InstitutionAdminParentStudentConnectionsScreen
    extends ConsumerStatefulWidget {
  const InstitutionAdminParentStudentConnectionsScreen({super.key});

  @override
  ConsumerState<InstitutionAdminParentStudentConnectionsScreen> createState() =>
      _InstitutionAdminParentStudentConnectionsScreenState();
}

class _InstitutionAdminParentStudentConnectionsScreenState
    extends ConsumerState<InstitutionAdminParentStudentConnectionsScreen> {
  InstitutionParentStudentPerspective _perspective =
      InstitutionParentStudentPerspective.byParent;
  final _searchControllers =
      <InstitutionParentStudentPerspective, TextEditingController>{
        InstitutionParentStudentPerspective.byParent: TextEditingController(),
        InstitutionParentStudentPerspective.byStudent: TextEditingController(),
      };
  final _connectFocusNode = FocusNode();
  final _headingFocusNode = FocusNode();
  final _disconnectFocusNodes = <String, FocusNode>{};

  @override
  void dispose() {
    for (final controller in _searchControllers.values) {
      controller.dispose();
    }
    for (final node in _disconnectFocusNodes.values) {
      node.dispose();
    }
    _connectFocusNode.dispose();
    _headingFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      institutionParentStudentRelationshipActionControllerProvider.select(
        (action) =>
            action.status ==
                InstitutionParentStudentRelationshipActionStatus.reconciling
            ? action.perspective
            : null,
      ),
      (_, perspective) {
        if (perspective != null && perspective != _perspective) {
          setState(() => _perspective = perspective);
        }
      },
    );
    final byParent = ref.watch(
      institutionParentStudentRelationshipListControllerProvider(
        InstitutionParentStudentPerspective.byParent,
      ),
    );
    final byStudent = ref.watch(
      institutionParentStudentRelationshipListControllerProvider(
        InstitutionParentStudentPerspective.byStudent,
      ),
    );
    final state = _perspective == InstitutionParentStudentPerspective.byParent
        ? byParent
        : byStudent;
    final actionState = ref.watch(
      institutionParentStudentRelationshipActionControllerProvider,
    );
    _syncSearchController(_perspective, state.searchDraft);
    final checking =
        state.status ==
        InstitutionParentStudentRelationshipListStatus.checkingCurrentState;
    final pageBlocked = actionState.hasOpenAction || checking;

    return SingleChildScrollView(
      key: const Key('institutionParentStudentConnectionsSurface'),
      padding: const EdgeInsets.all(_pagePadding),
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              key: const Key('institutionParentStudentConnectionsHeader'),
              spacing: _controlSpacing,
              runSpacing: _controlSpacing,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  header: true,
                  child: Focus(
                    focusNode: _headingFocusNode,
                    child: Text(
                      'Parent–Student Connections',
                      key: const Key(
                        'institutionParentStudentConnectionsHeading',
                      ),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
                FilledButton.icon(
                  key: const Key('institutionParentStudentConnectButton'),
                  focusNode: _connectFocusNode,
                  onPressed: pageBlocked ? null : _openConnectDialog,
                  icon: const Icon(Icons.link),
                  label: const Text('Connect Parent and Student'),
                ),
              ],
            ),
            const SizedBox(height: _sectionSpacing),
            SegmentedButton<InstitutionParentStudentPerspective>(
              key: const Key('institutionParentStudentPerspectiveSwitch'),
              segments: const [
                ButtonSegment(
                  value: InstitutionParentStudentPerspective.byParent,
                  label: Text('By Parent'),
                  icon: Icon(Icons.family_restroom_outlined),
                ),
                ButtonSegment(
                  value: InstitutionParentStudentPerspective.byStudent,
                  label: Text('By Student'),
                  icon: Icon(Icons.school_outlined),
                ),
              ],
              selected: {_perspective},
              onSelectionChanged: pageBlocked
                  ? null
                  : (selection) {
                      final next = selection.single;
                      if (next == _perspective) {
                        return;
                      }
                      setState(() => _perspective = next);
                      unawaited(
                        ref
                            .read(
                              institutionParentStudentRelationshipListControllerProvider(
                                next,
                              ).notifier,
                            )
                            .activate(),
                      );
                    },
            ),
            const SizedBox(height: _sectionSpacing),
            if (actionState.feedback case final feedback?) ...[
              _FeedbackBanner(
                message: feedback,
                onDismiss: actionState.isBusy
                    ? null
                    : ref
                          .read(
                            institutionParentStudentRelationshipActionControllerProvider
                                .notifier,
                          )
                          .clearFeedback,
              ),
              const SizedBox(height: _sectionSpacing),
            ],
            if (state.feedback case final feedback?) ...[
              _FeedbackBanner(message: feedback),
              const SizedBox(height: _sectionSpacing),
            ],
            _AnchorPanel(
              state: state,
              enabled: !pageBlocked && !state.isRequestInFlight,
              onSelect: _openAnchorPicker,
              onClear: () {
                ref
                    .read(
                      institutionParentStudentRelationshipListControllerProvider(
                        _perspective,
                      ).notifier,
                    )
                    .clearAnchor();
              },
            ),
            if (state.anchor != null) ...[
              const SizedBox(height: _sectionSpacing),
              _RelationshipToolbar(
                state: state,
                searchController: _searchControllers[_perspective]!,
                globallyBlocked: pageBlocked,
                controller: ref.read(
                  institutionParentStudentRelationshipListControllerProvider(
                    _perspective,
                  ).notifier,
                ),
              ),
            ],
            const SizedBox(height: _sectionSpacing),
            _RelationshipBody(
              state: state,
              globallyBlocked: pageBlocked,
              disconnectFocusNode: _disconnectFocusNode,
              onDisconnect: _openDisconnectDialog,
              onSelectAnchor: _openAnchorPicker,
              controller: ref.read(
                institutionParentStudentRelationshipListControllerProvider(
                  _perspective,
                ).notifier,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAnchorPicker() async {
    final purpose = _perspective == InstitutionParentStudentPerspective.byParent
        ? InstitutionUserSelectionPurpose.parentAnchor
        : InstitutionUserSelectionPurpose.studentAnchor;
    final current = ref
        .read(
          institutionParentStudentRelationshipListControllerProvider(
            _perspective,
          ),
        )
        .anchor;
    final selected = await showDialog<InstitutionUser>(
      context: context,
      builder: (_) =>
          _UserPickerDialog(purpose: purpose, initialSelected: current),
    );
    if (!mounted || selected == null) {
      return;
    }
    ref
        .read(
          institutionParentStudentRelationshipListControllerProvider(
            _perspective,
          ).notifier,
        )
        .selectAnchor(selected);
  }

  Future<void> _openConnectDialog() async {
    final controller = ref.read(
      institutionParentStudentRelationshipActionControllerProvider.notifier,
    );
    if (!controller.beginConnect()) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => const _ConnectDialog(),
    );
    if (!mounted) {
      return;
    }
    final current = ref.read(
      institutionParentStudentRelationshipActionControllerProvider,
    );
    if (current.isConnectDialog && !current.isBusy) {
      controller.cancelConnect();
    }
    _connectFocusNode.requestFocus();
  }

  Future<void> _openDisconnectDialog(
    InstitutionParentStudentRelationship relationship,
  ) async {
    final listState = ref.read(
      institutionParentStudentRelationshipListControllerProvider(_perspective),
    );
    final anchor = listState.anchor;
    if (anchor == null) {
      return;
    }
    final controller = ref.read(
      institutionParentStudentRelationshipActionControllerProvider.notifier,
    );
    if (!controller.beginDisconnect(
      perspective: _perspective,
      anchor: anchor,
      relationship: relationship,
    )) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => const _DisconnectDialog(),
    );
    if (!mounted) {
      return;
    }
    final current = ref.read(
      institutionParentStudentRelationshipActionControllerProvider,
    );
    if (current.isDisconnectDialog && !current.isBusy) {
      controller.cancelDisconnect();
    }
    final focusKey = controller.takeFocusKey();
    if (focusKey != null &&
        ref
            .read(
              institutionParentStudentRelationshipListControllerProvider(
                focusKey.identity.perspective,
              ).notifier,
            )
            .ownsCurrentRelationship(focusKey.identity)) {
      _disconnectFocusNode(
        focusKey.identity.perspective,
        focusKey.identity.relationship,
      ).requestFocus();
    } else {
      _headingFocusNode.requestFocus();
    }
  }

  FocusNode _disconnectFocusNode(
    InstitutionParentStudentPerspective perspective,
    InstitutionParentStudentRelationship relationship,
  ) {
    final key =
        '${perspective.name}:${relationship.id.toLowerCase()}:'
        '${relationship.startedAt.microsecondsSinceEpoch}';
    return _disconnectFocusNodes.putIfAbsent(key, FocusNode.new);
  }

  void _syncSearchController(
    InstitutionParentStudentPerspective perspective,
    String value,
  ) {
    final controller = _searchControllers[perspective]!;
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class _AnchorPanel extends StatelessWidget {
  const _AnchorPanel({
    required this.state,
    required this.enabled,
    required this.onSelect,
    required this.onClear,
  });

  final InstitutionParentStudentRelationshipListState state;
  final bool enabled;
  final VoidCallback onSelect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final anchor = state.anchor;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(_panelRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: anchor == null
            ? Wrap(
                spacing: _controlSpacing,
                runSpacing: _controlSpacing,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    state.perspective ==
                            InstitutionParentStudentPerspective.byParent
                        ? 'Select a Parent to view current Student connections.'
                        : 'Select a Student to view current Parent connections.',
                    key: const Key('institutionParentStudentNoAnchorPrompt'),
                  ),
                  OutlinedButton(
                    key: const Key('institutionParentStudentSelectAnchor'),
                    onPressed: enabled ? onSelect : null,
                    child: Text('Select ${state.perspective.anchorLabel}'),
                  ),
                ],
              )
            : Wrap(
                spacing: _controlSpacing,
                runSpacing: _controlSpacing,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    label:
                        'Selected ${state.perspective.anchorLabel}: '
                        '${anchor.fullName}, ${anchor.loginName}, '
                        '${anchor.isActive ? 'Active' : 'Inactive'}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          anchor.fullName,
                          key: const Key(
                            'institutionParentStudentAnchorFullName',
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(anchor.loginName),
                        Text(anchor.isActive ? 'Active' : 'Inactive'),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    key: const Key('institutionParentStudentChangeAnchor'),
                    onPressed: enabled ? onSelect : null,
                    child: const Text('Change'),
                  ),
                  TextButton(
                    key: const Key('institutionParentStudentClearAnchor'),
                    onPressed: enabled ? onClear : null,
                    child: const Text('Clear selection'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RelationshipToolbar extends StatelessWidget {
  const _RelationshipToolbar({
    required this.state,
    required this.searchController,
    required this.globallyBlocked,
    required this.controller,
  });

  final InstitutionParentStudentRelationshipListState state;
  final TextEditingController searchController;
  final bool globallyBlocked;
  final InstitutionParentStudentRelationshipListController controller;

  @override
  Widget build(BuildContext context) {
    final controlsEnabled = !globallyBlocked && state.canChangeQuery;
    return Wrap(
      key: const Key('institutionParentStudentRelationshipToolbar'),
      spacing: _controlSpacing,
      runSpacing: _controlSpacing,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            key: const Key('institutionParentStudentRelationshipSearch'),
            controller: searchController,
            enabled:
                !globallyBlocked &&
                !state.isRequestInFlight &&
                !state.projectionStale,
            decoration: InputDecoration(
              labelText:
                  state.perspective ==
                      InstitutionParentStudentPerspective.byParent
                  ? 'Search connected students'
                  : 'Search connected parents',
              border: const OutlineInputBorder(),
              errorText: state.searchErrorText,
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: controlsEnabled ? controller.commitSearchNow : null,
                icon: const Icon(Icons.search),
              ),
            ),
            textInputAction: TextInputAction.search,
            onChanged: controller.updateSearchDraft,
            onSubmitted: (_) => controller.commitSearchNow(),
          ),
        ),
        SizedBox(
          width: 180,
          child:
              DropdownButtonFormField<
                InstitutionParentStudentRelationshipStatusFilter?
              >(
                key: const Key('institutionParentStudentStatusFilter'),
                initialValue: state.query.status,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All statuses')),
                  DropdownMenuItem(
                    value:
                        InstitutionParentStudentRelationshipStatusFilter.active,
                    child: Text('Active'),
                  ),
                  DropdownMenuItem(
                    value: InstitutionParentStudentRelationshipStatusFilter
                        .inactive,
                    child: Text('Inactive'),
                  ),
                ],
                onChanged: controlsEnabled ? controller.setStatus : null,
              ),
        ),
        OutlinedButton.icon(
          key: const Key('institutionParentStudentClearFilters'),
          onPressed:
              !globallyBlocked &&
                  !state.isRequestInFlight &&
                  state.canClearFilters
              ? controller.clearFilters
              : null,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Clear filters'),
        ),
        OutlinedButton.icon(
          key: const Key('institutionParentStudentRefresh'),
          onPressed: controlsEnabled ? controller.refresh : null,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _RelationshipBody extends StatelessWidget {
  const _RelationshipBody({
    required this.state,
    required this.globallyBlocked,
    required this.disconnectFocusNode,
    required this.onDisconnect,
    required this.onSelectAnchor,
    required this.controller,
  });

  final InstitutionParentStudentRelationshipListState state;
  final bool globallyBlocked;
  final FocusNode Function(
    InstitutionParentStudentPerspective,
    InstitutionParentStudentRelationship,
  )
  disconnectFocusNode;
  final ValueChanged<InstitutionParentStudentRelationship> onDisconnect;
  final VoidCallback onSelectAnchor;
  final InstitutionParentStudentRelationshipListController controller;

  @override
  Widget build(BuildContext context) {
    if (state.status ==
        InstitutionParentStudentRelationshipListStatus.noAnchor) {
      return const SizedBox.shrink();
    }
    if (state.status ==
            InstitutionParentStudentRelationshipListStatus.loading ||
        state.status ==
            InstitutionParentStudentRelationshipListStatus.queryLoading) {
      return const _LiveProgress(label: 'Loading current connections');
    }
    if (state.status == InstitutionParentStudentRelationshipListStatus.error) {
      return _RelationshipError(
        failure: state.failure!,
        retrying: state.isRetryInFlight,
        onRetry: controller.retry,
      );
    }
    if (state.status ==
            InstitutionParentStudentRelationshipListStatus
                .checkingCurrentState &&
        state.result == null) {
      return const _LiveProgress(label: 'Checking current connections');
    }
    final result = state.result!;
    final checking =
        state.status ==
        InstitutionParentStudentRelationshipListStatus.checkingCurrentState;
    final refreshing =
        state.status ==
        InstitutionParentStudentRelationshipListStatus.refreshing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (checking || refreshing) ...[
          Semantics(
            liveRegion: true,
            label: checking
                ? 'Checking current connections'
                : 'Refreshing current connections',
            child: LinearProgressIndicator(
              key: Key(
                checking
                    ? 'institutionParentStudentChecking'
                    : 'institutionParentStudentRefreshing',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            checking
                ? 'Checking current connections'
                : 'Refreshing current connections',
          ),
          const SizedBox(height: 12),
        ],
        if (result.relationships.isEmpty)
          _RelationshipEmpty(state: state, onRetry: controller.refresh)
        else
          _RelationshipTable(
            state: state,
            result: result,
            enabled: !globallyBlocked && state.canChangeQuery,
            disconnectFocusNode: disconnectFocusNode,
            onDisconnect: onDisconnect,
            onSort: controller.toggleSort,
          ),
        const SizedBox(height: _sectionSpacing),
        _RelationshipPagination(
          state: state,
          result: result,
          globallyBlocked: globallyBlocked,
          onPrevious: controller.previousPage,
          onNext: controller.nextPage,
          onPerPageChanged: controller.setPerPage,
        ),
      ],
    );
  }
}

class _RelationshipTable extends StatefulWidget {
  const _RelationshipTable({
    required this.state,
    required this.result,
    required this.enabled,
    required this.disconnectFocusNode,
    required this.onDisconnect,
    required this.onSort,
  });

  final InstitutionParentStudentRelationshipListState state;
  final InstitutionParentStudentRelationshipListPage result;
  final bool enabled;
  final FocusNode Function(
    InstitutionParentStudentPerspective,
    InstitutionParentStudentRelationship,
  )
  disconnectFocusNode;
  final ValueChanged<InstitutionParentStudentRelationship> onDisconnect;
  final ValueChanged<InstitutionParentStudentRelationshipSort> onSort;

  @override
  State<_RelationshipTable> createState() => _RelationshipTableState();
}

class _RelationshipTableState extends State<_RelationshipTable> {
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
        key: const Key('institutionParentStudentHorizontalScroll'),
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: _tableMinWidth),
          child: DataTable(
            key: const Key('institutionParentStudentRelationshipTable'),
            sortColumnIndex:
                widget.state.query.sort ==
                    InstitutionParentStudentRelationshipSort.fullName
                ? 0
                : 4,
            sortAscending:
                widget.state.query.direction ==
                InstitutionParentStudentRelationshipSortDirection.asc,
            columns: [
              DataColumn(
                label: Text(widget.state.perspective.relatedLabel),
                onSort: widget.enabled
                    ? (_, _) => widget.onSort(
                        InstitutionParentStudentRelationshipSort.fullName,
                      )
                    : null,
              ),
              const DataColumn(label: Text('Login name')),
              const DataColumn(label: Text('Contact')),
              const DataColumn(label: Text('Status')),
              DataColumn(
                label: const Text('Connected'),
                onSort: widget.enabled
                    ? (_, _) => widget.onSort(
                        InstitutionParentStudentRelationshipSort.startedAt,
                      )
                    : null,
              ),
              const DataColumn(label: Text('Action')),
            ],
            rows: [
              for (final relationship in widget.result.relationships)
                DataRow(
                  key: ValueKey(
                    'institutionParentStudentRow${relationship.id}',
                  ),
                  cells: [
                    DataCell(_BoundedText(relationship.relatedUser.fullName)),
                    DataCell(_BoundedText(relationship.relatedUser.loginName)),
                    DataCell(_RelatedContact(user: relationship.relatedUser)),
                    DataCell(
                      Text(
                        relationship.relatedUser.isActive
                            ? 'Active'
                            : 'Inactive',
                      ),
                    ),
                    DataCell(
                      Text(formatInstitutionUserUtc(relationship.startedAt)),
                    ),
                    DataCell(
                      TextButton(
                        key: ValueKey(
                          'institutionParentStudentDisconnect${relationship.id}',
                        ),
                        focusNode: widget.disconnectFocusNode(
                          widget.state.perspective,
                          relationship,
                        ),
                        onPressed: widget.enabled
                            ? () => widget.onDisconnect(relationship)
                            : null,
                        child: const Text('Disconnect'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelationshipPagination extends StatelessWidget {
  const _RelationshipPagination({
    required this.state,
    required this.result,
    required this.globallyBlocked,
    required this.onPrevious,
    required this.onNext,
    required this.onPerPageChanged,
  });

  final InstitutionParentStudentRelationshipListState state;
  final InstitutionParentStudentRelationshipListPage result;
  final bool globallyBlocked;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onPerPageChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = !globallyBlocked && state.canChangeQuery;
    final pagination = result.pagination;
    final range = result.relationships.isEmpty
        ? '0-0 of ${pagination.total}'
        : '${result.rangeStart}-${result.rangeEnd} of ${pagination.total}';
    return Wrap(
      key: const Key('institutionParentStudentPagination'),
      spacing: _controlSpacing,
      runSpacing: _controlSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(range),
        Text('Page ${pagination.page} of ${pagination.lastPage}'),
        OutlinedButton.icon(
          key: const Key('institutionParentStudentPrevious'),
          onPressed: enabled && state.canGoPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Previous'),
        ),
        OutlinedButton.icon(
          key: const Key('institutionParentStudentNext'),
          onPressed: enabled && state.canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
        SizedBox(
          width: 148,
          child: DropdownButtonFormField<int>(
            key: const Key('institutionParentStudentPageSize'),
            initialValue: state.query.perPage,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Page size',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final size
                  in InstitutionParentStudentRelationshipQuery.pageSizeOptions)
                DropdownMenuItem(value: size, child: Text('$size')),
            ],
            onChanged: enabled
                ? (value) {
                    if (value != null) {
                      onPerPageChanged(value);
                    }
                  }
                : null,
          ),
        ),
      ],
    );
  }
}

class _RelationshipEmpty extends StatelessWidget {
  const _RelationshipEmpty({required this.state, required this.onRetry});

  final InstitutionParentStudentRelationshipListState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final related = state.perspective.relatedLabel;
    final filtered =
        state.status ==
        InstitutionParentStudentRelationshipListStatus.filteredEmpty;
    final emptyPage =
        state.status ==
        InstitutionParentStudentRelationshipListStatus.emptyPage;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(_panelRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                emptyPage
                    ? 'No connections on this page'
                    : filtered
                    ? 'No matching $related connections'
                    : 'No current $related connections',
                key: const Key('institutionParentStudentEmptyTitle'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (emptyPage) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Refresh'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RelationshipError extends StatelessWidget {
  const _RelationshipError({
    required this.failure,
    required this.retrying,
    required this.onRetry,
  });

  final ApiFailure failure;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Text(
                'Unable to load connections',
                key: const Key('institutionParentStudentErrorTitle'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(_relationshipFailureMessage(failure)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: retrying ? null : onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retrying ? 'Retrying' : 'Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserPickerDialog extends ConsumerStatefulWidget {
  const _UserPickerDialog({
    required this.purpose,
    required this.initialSelected,
  });

  final InstitutionUserSelectionPurpose purpose;
  final InstitutionUser? initialSelected;

  @override
  ConsumerState<_UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends ConsumerState<_UserPickerDialog> {
  final _searchController = TextEditingController();
  var _opening = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(
            institutionUserSelectionControllerProvider(widget.purpose).notifier,
          )
          .open(selected: widget.initialSelected);
      setState(() => _opening = false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contentHeight = (MediaQuery.sizeOf(context).height - 180)
        .clamp(280.0, 520.0)
        .toDouble();
    final state = ref.watch(
      institutionUserSelectionControllerProvider(widget.purpose),
    );
    final controller = ref.read(
      institutionUserSelectionControllerProvider(widget.purpose).notifier,
    );
    _syncTextController(_searchController, state.searchDraft);
    if (!state.isOpen && !_opening) {
      _closeAfterFrame(context);
    }
    return AlertDialog(
      key: const Key('institutionParentStudentAnchorPicker'),
      title: Text(widget.purpose.title),
      content: SizedBox(
        width: 620,
        height: contentHeight,
        child: _UserSelectionContent(
          state: state,
          controller: controller,
          searchController: _searchController,
          busy: false,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('institutionParentStudentAnchorSelect'),
          onPressed: state.selected == null
              ? null
              : () => Navigator.of(context).pop(state.selected),
          child: const Text('Select'),
        ),
      ],
    );
  }
}

class _ConnectDialog extends ConsumerStatefulWidget {
  const _ConnectDialog();

  @override
  ConsumerState<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends ConsumerState<_ConnectDialog> {
  InstitutionUserSelectionPurpose _purpose =
      InstitutionUserSelectionPurpose.activeParent;
  final _searchControllers =
      <InstitutionUserSelectionPurpose, TextEditingController>{
        InstitutionUserSelectionPurpose.activeParent: TextEditingController(),
        InstitutionUserSelectionPurpose.activeStudent: TextEditingController(),
      };

  @override
  void dispose() {
    for (final controller in _searchControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contentHeight = (MediaQuery.sizeOf(context).height - 180)
        .clamp(360.0, 650.0)
        .toDouble();
    final actionState = ref.watch(
      institutionParentStudentRelationshipActionControllerProvider,
    );
    final parentState = ref.watch(
      institutionUserSelectionControllerProvider(
        InstitutionUserSelectionPurpose.activeParent,
      ),
    );
    final studentState = ref.watch(
      institutionUserSelectionControllerProvider(
        InstitutionUserSelectionPurpose.activeStudent,
      ),
    );
    if (!actionState.isConnectDialog) {
      _closeAfterFrame(context);
    }
    final state = _purpose == InstitutionUserSelectionPurpose.activeParent
        ? parentState
        : studentState;
    final selectionController = ref.read(
      institutionUserSelectionControllerProvider(_purpose).notifier,
    );
    _syncTextController(_searchControllers[_purpose]!, state.searchDraft);
    final busy = actionState.isBusy;
    final canConnect =
        !busy && parentState.selected != null && studentState.selected != null;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        key: const Key('institutionParentStudentConnectDialog'),
        title: const Text('Connect Parent and Student'),
        content: SizedBox(
          width: 700,
          height: contentHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<InstitutionUserSelectionPurpose>(
                key: const Key('institutionParentStudentConnectSelectorMode'),
                segments: const [
                  ButtonSegment(
                    value: InstitutionUserSelectionPurpose.activeParent,
                    label: Text('Parent'),
                  ),
                  ButtonSegment(
                    value: InstitutionUserSelectionPurpose.activeStudent,
                    label: Text('Student'),
                  ),
                ],
                selected: {_purpose},
                onSelectionChanged: busy
                    ? null
                    : (selection) =>
                          setState(() => _purpose = selection.single),
              ),
              const SizedBox(height: 12),
              _ConnectSelectedSummary(
                label: 'Parent',
                user: parentState.selected,
                errorText: actionState.parentError,
                busy: busy,
                onChange: () => setState(
                  () => _purpose = InstitutionUserSelectionPurpose.activeParent,
                ),
                onClear: () => ref
                    .read(
                      institutionUserSelectionControllerProvider(
                        InstitutionUserSelectionPurpose.activeParent,
                      ).notifier,
                    )
                    .select(null),
              ),
              const SizedBox(height: 8),
              _ConnectSelectedSummary(
                label: 'Student',
                user: studentState.selected,
                errorText: actionState.studentError,
                busy: busy,
                onChange: () => setState(
                  () =>
                      _purpose = InstitutionUserSelectionPurpose.activeStudent,
                ),
                onClear: () => ref
                    .read(
                      institutionUserSelectionControllerProvider(
                        InstitutionUserSelectionPurpose.activeStudent,
                      ).notifier,
                    )
                    .select(null),
              ),
              if (actionState.formMessage case final message?) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    key: const Key('institutionParentStudentConnectError'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: _UserSelectionContent(
                  state: state,
                  controller: selectionController,
                  searchController: _searchControllers[_purpose]!,
                  busy: busy,
                ),
              ),
              if (busy) ...[
                const SizedBox(height: 12),
                const _LiveProgress(label: 'Connecting Parent and Student'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('institutionParentStudentConnectCancel'),
            onPressed: busy
                ? null
                : ref
                      .read(
                        institutionParentStudentRelationshipActionControllerProvider
                            .notifier,
                      )
                      .cancelConnect,
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('institutionParentStudentConnectConfirm'),
            onPressed: canConnect
                ? ref
                      .read(
                        institutionParentStudentRelationshipActionControllerProvider
                            .notifier,
                      )
                      .submitConnect
                : null,
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

class _ConnectSelectedSummary extends StatelessWidget {
  const _ConnectSelectedSummary({
    required this.label,
    required this.user,
    required this.errorText,
    required this.busy,
    required this.onChange,
    required this.onClear,
  });

  final String label;
  final InstitutionUser? user;
  final String? errorText;
  final bool busy;
  final VoidCallback onChange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: errorText == null
              ? Theme.of(context).dividerColor
              : Theme.of(context).colorScheme.error,
        ),
        borderRadius: BorderRadius.circular(_panelRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              user == null
                  ? '$label not selected'
                  : '$label: ${user!.fullName} (${user!.loginName})',
            ),
            TextButton(
              onPressed: busy ? null : onChange,
              child: const Text('Change'),
            ),
            if (user != null)
              TextButton(
                onPressed: busy ? null : onClear,
                child: const Text('Clear'),
              ),
            if (errorText != null)
              Text(
                errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserSelectionContent extends StatelessWidget {
  const _UserSelectionContent({
    required this.state,
    required this.controller,
    required this.searchController,
    required this.busy,
  });

  final InstitutionUserSelectionState state;
  final InstitutionUserSelectionController controller;
  final TextEditingController searchController;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final readBlocked = busy || state.isRequestInFlight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: ValueKey('institutionUserSelectionSearch${state.purpose.name}'),
          controller: searchController,
          enabled: !readBlocked,
          decoration: InputDecoration(
            labelText: 'Search ${state.purpose.title}',
            border: const OutlineInputBorder(),
            errorText: state.searchErrorText,
            suffixIcon: IconButton(
              tooltip: 'Search',
              onPressed: readBlocked ? null : controller.commitSearchNow,
              icon: const Icon(Icons.search),
            ),
          ),
          textInputAction: TextInputAction.search,
          onChanged: controller.updateSearchDraft,
          onSubmitted: (_) => controller.commitSearchNow(),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _UserSelectionResults(state: state, controller: controller),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(state.query == null ? 'Page 1' : 'Page ${state.query!.page}'),
            OutlinedButton(
              onPressed: busy || !state.canGoPrevious
                  ? null
                  : controller.previousPage,
              child: const Text('Previous'),
            ),
            OutlinedButton(
              onPressed: busy || !state.canGoNext ? null : controller.nextPage,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}

class _UserSelectionResults extends StatelessWidget {
  const _UserSelectionResults({required this.state, required this.controller});

  final InstitutionUserSelectionState state;
  final InstitutionUserSelectionController controller;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      InstitutionUserSelectionStatus.loading => const _LiveProgress(
        label: 'Loading user choices',
      ),
      InstitutionUserSelectionStatus.error => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Unable to load user choices'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: state.isRetryInFlight ? null : controller.retry,
              child: Text(state.isRetryInFlight ? 'Retrying' : 'Retry'),
            ),
          ],
        ),
      ),
      InstitutionUserSelectionStatus.empty => const Center(
        child: Text('No matching users'),
      ),
      InstitutionUserSelectionStatus.emptyPage => const Center(
        child: Text('No users on this page'),
      ),
      InstitutionUserSelectionStatus.data => ListView.builder(
        key: ValueKey('institutionUserSelectionResults${state.purpose.name}'),
        itemCount: state.result!.users.length,
        itemBuilder: (context, index) {
          final user = state.result!.users[index];
          final selected =
              identical(state.selected, user) ||
              state.selected?.id.toLowerCase() == user.id.toLowerCase();
          return Semantics(
            selected: selected,
            button: true,
            label:
                '${user.fullName}, ${user.loginName}, '
                '${user.isActive ? 'Active' : 'Inactive'}',
            child: ListTile(
              key: ValueKey('institutionUserSelection${user.id}'),
              selected: selected,
              title: Text(user.fullName),
              subtitle: Text(
                '${user.loginName} · ${user.isActive ? 'Active' : 'Inactive'}',
              ),
              trailing: selected ? const Icon(Icons.check_circle) : null,
              onTap: () => controller.select(user),
            ),
          );
        },
      ),
      InstitutionUserSelectionStatus.closed => const SizedBox.shrink(),
    };
  }
}

class _DisconnectDialog extends ConsumerWidget {
  const _DisconnectDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      institutionParentStudentRelationshipActionControllerProvider,
    );
    if (!state.isDisconnectDialog) {
      _closeAfterFrame(context);
    }
    final anchor = state.anchor;
    final relationship = state.relationship;
    final perspective = state.perspective;
    final busy = state.isBusy;
    final parentName =
        anchor == null || relationship == null || perspective == null
        ? ''
        : perspective == InstitutionParentStudentPerspective.byParent
        ? anchor.fullName
        : relationship.relatedUser.fullName;
    final studentName =
        anchor == null || relationship == null || perspective == null
        ? ''
        : perspective == InstitutionParentStudentPerspective.byStudent
        ? anchor.fullName
        : relationship.relatedUser.fullName;
    final controller = ref.read(
      institutionParentStudentRelationshipActionControllerProvider.notifier,
    );
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        key: const Key('institutionParentStudentDisconnectDialog'),
        title: const Text('Disconnect Parent and Student?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Parent: $parentName. Student: $studentName.',
              child: Text('Parent: $parentName\nStudent: $studentName'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Disconnecting ends the current Parent–Student relationship and '
              'revokes future relationship-based access. Historical relationship '
              'records are preserved. Neither user account is deactivated or deleted.',
            ),
            if (busy) ...[
              const SizedBox(height: 16),
              const _LiveProgress(label: 'Disconnecting Parent and Student'),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('institutionParentStudentDisconnectCancel'),
            onPressed: busy ? null : controller.cancelDisconnect,
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('institutionParentStudentDisconnectConfirm'),
            onPressed: busy ? null : controller.confirmDisconnect,
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}

class _RelatedContact extends StatelessWidget {
  const _RelatedContact({required this.user});

  final InstitutionParentStudentRelatedUser user;

  @override
  Widget build(BuildContext context) {
    final values = <String>[?user.email, ?user.phone];
    return Text(values.isEmpty ? 'Not provided' : values.join('\n'));
  }
}

class _BoundedText extends StatelessWidget {
  const _BoundedText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: value,
      child: SizedBox(
        width: 190,
        child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _LiveProgress extends StatelessWidget {
  const _LiveProgress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: label,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: onDismiss == null
          ? Material(
              key: const Key('institutionParentStudentFeedback'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(message),
              ),
            )
          : MaterialBanner(
              key: const Key('institutionParentStudentFeedback'),
              content: Text(message),
              actions: [
                TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
              ],
            ),
    );
  }
}

String _relationshipFailureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.forbidden =>
      'You do not have permission to view Parent–Student connections.',
    ApiErrorCodes.validationFailed =>
      'The connection list request did not match the server contract.',
    _ => switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The connection list request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected connection list response.',
      ApiFailureKind.cancelled => 'The connection list request was cancelled.',
      ApiFailureKind.unknown ||
      ApiFailureKind.server ||
      ApiFailureKind.validation => 'The connection list could not be loaded.',
    },
  };
}

void _syncTextController(TextEditingController controller, String value) {
  if (controller.text == value) {
    return;
  }
  controller.value = TextEditingValue(
    text: value,
    selection: TextSelection.collapsed(offset: value.length),
  );
}

void _closeAfterFrame(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  });
}
