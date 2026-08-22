import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';

import '../application/institution_group_action_controller.dart';
import '../application/institution_group_membership_action_controller.dart';
import '../application/institution_group_membership_candidate_controller.dart';
import '../application/institution_group_membership_candidate_state.dart';
import '../application/institution_group_membership_list_controller.dart';
import '../application/institution_group_membership_list_state.dart';
import '../domain/institution_group.dart';
import '../domain/institution_group_membership.dart';
import '../domain/institution_group_membership_query.dart';
import '../domain/institution_user.dart';
import 'institution_admin_group_formatters.dart';

class InstitutionGroupMembershipSections extends ConsumerStatefulWidget {
  const InstitutionGroupMembershipSections({
    required this.groupId,
    required this.group,
    required this.detailAllowsMutation,
    super.key,
  });

  final String groupId;
  final InstitutionGroup group;
  final bool detailAllowsMutation;

  @override
  ConsumerState<InstitutionGroupMembershipSections> createState() =>
      _InstitutionGroupMembershipSectionsState();
}

class _InstitutionGroupMembershipSectionsState
    extends ConsumerState<InstitutionGroupMembershipSections> {
  final _assignFocusNodes = <InstitutionGroupMemberKind, FocusNode>{
    InstitutionGroupMemberKind.teacher: FocusNode(),
    InstitutionGroupMemberKind.student: FocusNode(),
  };
  final _headingFocusNodes = <InstitutionGroupMemberKind, FocusNode>{
    InstitutionGroupMemberKind.teacher: FocusNode(),
    InstitutionGroupMemberKind.student: FocusNode(),
  };
  final _removeFocusNodes = <String, FocusNode>{};

  @override
  void dispose() {
    for (final node in _assignFocusNodes.values) {
      node.dispose();
    }
    for (final node in _headingFocusNodes.values) {
      node.dispose();
    }
    for (final node in _removeFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupAction = ref.watch(
      institutionGroupActionControllerProvider(widget.groupId),
    );
    final membershipAction = ref.watch(
      institutionGroupMembershipActionControllerProvider(widget.groupId),
    );
    for (final kind in InstitutionGroupMemberKind.values) {
      ref.watch(
        institutionGroupMembershipCandidateControllerProvider(_key(kind)),
      );
    }
    final canStartMutation =
        widget.detailAllowsMutation &&
        widget.group.status == InstitutionGroupStatus.active &&
        !groupAction.hasOpenAction &&
        !membershipAction.hasOpenAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kind in InstitutionGroupMemberKind.values) ...[
          _MembershipSection(
            key: Key('institutionGroup${kind.sectionTitle}Section'),
            group: widget.group,
            kind: kind,
            listKey: _key(kind),
            headingFocusNode: _headingFocusNodes[kind]!,
            assignFocusNode: _assignFocusNodes[kind]!,
            canStartMutation: canStartMutation,
            queryControlsEnabled: !membershipAction.hasOpenAction,
            removeFocusNode: _removeFocusNode,
            onAssign: () => _openAssignment(kind),
            onRemove: (membership) => _openRemove(kind, membership),
          ),
          if (kind != InstitutionGroupMemberKind.values.last)
            const SizedBox(height: 24),
        ],
      ],
    );
  }

  InstitutionGroupMembershipListKey _key(InstitutionGroupMemberKind kind) =>
      InstitutionGroupMembershipListKey(groupId: widget.groupId, kind: kind);

  FocusNode _removeFocusNode(
    InstitutionGroupMemberKind kind,
    InstitutionGroupMembership membership,
  ) {
    final key = _removeFocusKey(kind, membership);
    return _removeFocusNodes.putIfAbsent(key, FocusNode.new);
  }

  String _removeFocusKey(
    InstitutionGroupMemberKind kind,
    InstitutionGroupMembership membership,
  ) =>
      '${kind.name}:${membership.id.toLowerCase()}:${membership.startedAt.toIso8601String()}';

  Future<void> _openAssignment(InstitutionGroupMemberKind kind) async {
    final controller = ref.read(
      institutionGroupMembershipActionControllerProvider(
        widget.groupId,
      ).notifier,
    );
    if (!controller.beginAssign(widget.group, kind)) {
      return;
    }
    final focusKey = controller.focusKey!;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          _MembershipAssignmentDialog(groupId: widget.groupId, kind: kind),
    );
    if (!mounted) {
      return;
    }
    final current = ref.read(
      institutionGroupMembershipActionControllerProvider(widget.groupId),
    );
    if (!current.isBusy && current.isAssignDialog) {
      controller.dismiss();
    }
    _restoreFocus(controller, focusKey);
  }

  Future<void> _openRemove(
    InstitutionGroupMemberKind kind,
    InstitutionGroupMembership membership,
  ) async {
    final controller = ref.read(
      institutionGroupMembershipActionControllerProvider(
        widget.groupId,
      ).notifier,
    );
    if (!controller.beginRemove(
      selected: widget.group,
      kind: kind,
      membership: membership,
    )) {
      return;
    }
    final focusKey = controller.focusKey!;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _MembershipRemoveDialog(groupId: widget.groupId),
    );
    if (!mounted) {
      return;
    }
    final current = ref.read(
      institutionGroupMembershipActionControllerProvider(widget.groupId),
    );
    if (!current.isBusy && current.isRemoveDialog) {
      controller.dismiss();
    }
    _restoreFocus(controller, focusKey);
  }

  void _restoreFocus(
    InstitutionGroupMembershipActionController controller,
    InstitutionGroupMembershipActionFocusKey focusKey,
  ) {
    if (controller.canRestoreFocus(focusKey)) {
      if (!focusKey.isRemove) {
        _assignFocusNodes[focusKey.memberKind]!.requestFocus();
        return;
      }
      final member = focusKey.membership;
      if (member != null) {
        _removeFocusNode(focusKey.memberKind, member).requestFocus();
        return;
      }
    }
    _headingFocusNodes[focusKey.memberKind]!.requestFocus();
  }
}

class _MembershipSection extends ConsumerStatefulWidget {
  const _MembershipSection({
    required super.key,
    required this.group,
    required this.kind,
    required this.listKey,
    required this.headingFocusNode,
    required this.assignFocusNode,
    required this.canStartMutation,
    required this.queryControlsEnabled,
    required this.removeFocusNode,
    required this.onAssign,
    required this.onRemove,
  });

  final InstitutionGroup group;
  final InstitutionGroupMemberKind kind;
  final InstitutionGroupMembershipListKey listKey;
  final FocusNode headingFocusNode;
  final FocusNode assignFocusNode;
  final bool canStartMutation;
  final bool queryControlsEnabled;
  final FocusNode Function(
    InstitutionGroupMemberKind,
    InstitutionGroupMembership,
  )
  removeFocusNode;
  final VoidCallback onAssign;
  final ValueChanged<InstitutionGroupMembership> onRemove;

  @override
  ConsumerState<_MembershipSection> createState() => _MembershipSectionState();
}

class _MembershipSectionState extends ConsumerState<_MembershipSection> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      institutionGroupMembershipListControllerProvider(widget.listKey),
    );
    final controller = ref.read(
      institutionGroupMembershipListControllerProvider(widget.listKey).notifier,
    );
    if (_searchController.text != state.searchDraft) {
      _searchController.value = TextEditingValue(
        text: state.searchDraft,
        selection: TextSelection.collapsed(offset: state.searchDraft.length),
      );
    }
    final archived = widget.group.status == InstitutionGroupStatus.archived;
    final controlsEnabled =
        widget.queryControlsEnabled && !state.isRequestInFlight;
    final canMutateRows = widget.canStartMutation && !state.isRequestInFlight;

    return Semantics(
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    header: true,
                    child: Focus(
                      focusNode: widget.headingFocusNode,
                      child: Text(
                        widget.kind.sectionTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  if (!archived)
                    FilledButton.icon(
                      key: Key(
                        'institutionGroupAssign${widget.kind.sectionTitle}',
                      ),
                      focusNode: widget.assignFocusNode,
                      onPressed:
                          widget.canStartMutation && !state.isRequestInFlight
                          ? widget.onAssign
                          : null,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(widget.kind.assignTitle),
                    ),
                ],
              ),
              if (archived) ...[
                const SizedBox(height: 12),
                const Text(
                  'Membership changes are unavailable because this group is archived.',
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      key: Key(
                        'institutionGroup${widget.kind.sectionTitle}Search',
                      ),
                      controller: _searchController,
                      enabled: controlsEnabled,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Search ${widget.kind.lowerPlural}',
                        errorText: state.searchErrorText,
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: controller.updateSearchDraft,
                      onSubmitted: (_) => controller.commitSearchNow(),
                    ),
                  ),
                  DropdownButton<InstitutionGroupMembershipStatusFilter?>(
                    key: Key(
                      'institutionGroup${widget.kind.sectionTitle}Status',
                    ),
                    value: state.query.status,
                    onChanged: controlsEnabled ? controller.setStatus : null,
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      DropdownMenuItem(
                        value: InstitutionGroupMembershipStatusFilter.active,
                        child: Text('Active'),
                      ),
                      DropdownMenuItem(
                        value: InstitutionGroupMembershipStatusFilter.inactive,
                        child: Text('Inactive'),
                      ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: state.canClearFilters && controlsEnabled
                        ? controller.clearFilters
                        : null,
                    child: const Text('Clear filters'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controlsEnabled ? controller.refresh : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MembershipResult(
                state: state,
                kind: widget.kind,
                showMutationActions: !archived,
                canMutateRows: canMutateRows && !archived,
                removeFocusNode: widget.removeFocusNode,
                onRemove: widget.onRemove,
                onRetry: controller.retry,
                onClear: controller.clearFilters,
                onSort: controller.toggleSort,
              ),
              if (state.result != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${state.result!.rangeStart}-${state.result!.rangeEnd} of ${state.result!.pagination.total}',
                    ),
                    OutlinedButton(
                      onPressed: state.canGoPrevious && controlsEnabled
                          ? controller.previousPage
                          : null,
                      child: const Text('Previous'),
                    ),
                    OutlinedButton(
                      onPressed: state.canGoNext && controlsEnabled
                          ? controller.nextPage
                          : null,
                      child: const Text('Next'),
                    ),
                    DropdownButton<int>(
                      value: state.query.perPage,
                      onChanged: controlsEnabled
                          ? (value) {
                              if (value != null) {
                                controller.setPerPage(value);
                              }
                            }
                          : null,
                      items: InstitutionGroupMembershipQuery.pageSizeOptions
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text('$value per page'),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MembershipResult extends StatelessWidget {
  const _MembershipResult({
    required this.state,
    required this.kind,
    required this.showMutationActions,
    required this.canMutateRows,
    required this.removeFocusNode,
    required this.onRemove,
    required this.onRetry,
    required this.onClear,
    required this.onSort,
  });

  final InstitutionGroupMembershipListState state;
  final InstitutionGroupMemberKind kind;
  final bool showMutationActions;
  final bool canMutateRows;
  final FocusNode Function(
    InstitutionGroupMemberKind,
    InstitutionGroupMembership,
  )
  removeFocusNode;
  final ValueChanged<InstitutionGroupMembership> onRemove;
  final VoidCallback onRetry;
  final VoidCallback onClear;
  final ValueChanged<InstitutionGroupMembershipSort> onSort;

  @override
  Widget build(BuildContext context) {
    if (state.status == InstitutionGroupMembershipListStatus.loading ||
        state.status == InstitutionGroupMembershipListStatus.queryLoading) {
      return Semantics(
        liveRegion: true,
        label: 'Loading ${kind.lowerPlural}',
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (state.status ==
        InstitutionGroupMembershipListStatus.checkingCurrentState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            label: 'Checking current ${kind.lowerPlural}',
            child: const LinearProgressIndicator(),
          ),
          const SizedBox(height: 12),
          if (state.result != null)
            Opacity(
              opacity: 0.55,
              child: _MembershipTable(
                state: state,
                kind: kind,
                showMutationActions: showMutationActions,
                canMutateRows: false,
                removeFocusNode: removeFocusNode,
                onRemove: onRemove,
                onSort: null,
              ),
            ),
        ],
      );
    }
    if (state.status == InstitutionGroupMembershipListStatus.error) {
      return Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unable to load ${kind.lowerPlural}'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: state.isRetryInFlight ? null : onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (state.status == InstitutionGroupMembershipListStatus.globalEmpty) {
      return Text('No ${kind.lowerPlural} assigned');
    }
    if (state.status == InstitutionGroupMembershipListStatus.filteredEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No matching ${kind.lowerPlural}'),
          TextButton(onPressed: onClear, child: const Text('Clear filters')),
        ],
      );
    }
    if (state.result == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.status == InstitutionGroupMembershipListStatus.refreshing)
          Semantics(
            liveRegion: true,
            label: 'Refreshing ${kind.lowerPlural}',
            child: const LinearProgressIndicator(),
          ),
        _MembershipTable(
          state: state,
          kind: kind,
          showMutationActions: showMutationActions,
          canMutateRows: canMutateRows,
          removeFocusNode: removeFocusNode,
          onRemove: onRemove,
          onSort: onSort,
        ),
      ],
    );
  }
}

class _MembershipTable extends StatefulWidget {
  const _MembershipTable({
    required this.state,
    required this.kind,
    required this.showMutationActions,
    required this.canMutateRows,
    required this.removeFocusNode,
    required this.onRemove,
    required this.onSort,
  });

  final InstitutionGroupMembershipListState state;
  final InstitutionGroupMemberKind kind;
  final bool showMutationActions;
  final bool canMutateRows;
  final FocusNode Function(
    InstitutionGroupMemberKind,
    InstitutionGroupMembership,
  )
  removeFocusNode;
  final ValueChanged<InstitutionGroupMembership> onRemove;
  final ValueChanged<InstitutionGroupMembershipSort>? onSort;

  @override
  State<_MembershipTable> createState() => _MembershipTableState();
}

class _MembershipTableState extends State<_MembershipTable> {
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
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(
              label: Semantics(
                button: true,
                sortKey: OrdinalSortKey(
                  widget.state.query.sort ==
                          InstitutionGroupMembershipSort.fullName
                      ? 0
                      : 1,
                ),
                label:
                    'Full name, ${_sortDescription(InstitutionGroupMembershipSort.fullName)}',
                child: TextButton(
                  onPressed: widget.onSort == null
                      ? null
                      : () => widget.onSort!(
                          InstitutionGroupMembershipSort.fullName,
                        ),
                  child: const Text('Full name'),
                ),
              ),
            ),
            const DataColumn(label: Text('Login name')),
            const DataColumn(label: Text('Contact')),
            const DataColumn(label: Text('Status')),
            DataColumn(
              label: Semantics(
                button: true,
                label:
                    'Assigned, ${_sortDescription(InstitutionGroupMembershipSort.startedAt)}',
                child: TextButton(
                  onPressed: widget.onSort == null
                      ? null
                      : () => widget.onSort!(
                          InstitutionGroupMembershipSort.startedAt,
                        ),
                  child: const Text('Assigned'),
                ),
              ),
            ),
            const DataColumn(label: Text('Action')),
          ],
          rows: [
            for (final membership in widget.state.result!.memberships)
              DataRow(
                cells: [
                  DataCell(Text(membership.fullName)),
                  DataCell(Text(membership.loginName)),
                  DataCell(Text(_contact(membership))),
                  DataCell(Text(membership.isActive ? 'Active' : 'Inactive')),
                  DataCell(
                    Text(formatInstitutionGroupUtc(membership.startedAt)),
                  ),
                  DataCell(
                    widget.showMutationActions
                        ? TextButton(
                            key: Key(
                              'remove${widget.kind.singularTitle}-${membership.id}-${membership.startedAt.toIso8601String()}',
                            ),
                            focusNode: widget.removeFocusNode(
                              widget.kind,
                              membership,
                            ),
                            onPressed: widget.canMutateRows
                                ? () => widget.onRemove(membership)
                                : null,
                            child: const Text('Remove'),
                          )
                        : const Text('—'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _sortDescription(InstitutionGroupMembershipSort sort) {
    if (widget.state.query.sort != sort) {
      return 'not sorted';
    }
    return widget.state.query.direction ==
            InstitutionGroupMembershipSortDirection.asc
        ? 'sorted ascending'
        : 'sorted descending';
  }

  String _contact(InstitutionGroupMembership membership) {
    final values = [membership.email, membership.phone].whereType<String>();
    return values.isEmpty ? 'Not provided' : values.join(' / ');
  }
}

class _MembershipAssignmentDialog extends ConsumerStatefulWidget {
  const _MembershipAssignmentDialog({
    required this.groupId,
    required this.kind,
  });

  final String groupId;
  final InstitutionGroupMemberKind kind;

  @override
  ConsumerState<_MembershipAssignmentDialog> createState() =>
      _MembershipAssignmentDialogState();
}

class _MembershipAssignmentDialogState
    extends ConsumerState<_MembershipAssignmentDialog> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = InstitutionGroupMembershipListKey(
      groupId: widget.groupId,
      kind: widget.kind,
    );
    final candidateState = ref.watch(
      institutionGroupMembershipCandidateControllerProvider(key),
    );
    final candidateController = ref.read(
      institutionGroupMembershipCandidateControllerProvider(key).notifier,
    );
    final actionState = ref.watch(
      institutionGroupMembershipActionControllerProvider(widget.groupId),
    );
    final actionController = ref.read(
      institutionGroupMembershipActionControllerProvider(
        widget.groupId,
      ).notifier,
    );
    if (!actionState.isAssignDialog || !candidateState.isOpen) {
      _closeStaleDialog();
      return const SizedBox.shrink();
    }
    if (_searchController.text != candidateState.searchDraft) {
      _searchController.value = TextEditingValue(
        text: candidateState.searchDraft,
        selection: TextSelection.collapsed(
          offset: candidateState.searchDraft.length,
        ),
      );
    }
    final busy = actionState.isBusy;
    final candidateSettled =
        candidateState.status ==
            InstitutionGroupMembershipCandidateStatus.data ||
        candidateState.status ==
            InstitutionGroupMembershipCandidateStatus.empty ||
        candidateState.status ==
            InstitutionGroupMembershipCandidateStatus.emptyPage;
    final canSubmit =
        !busy &&
        candidateSettled &&
        candidateState.searchErrorText == null &&
        candidateState.selected.isNotEmpty;

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        key: Key('assign${widget.kind.sectionTitle}Dialog'),
        title: Text(widget.kind.assignTitle),
        content: SizedBox(
          width: 720,
          height: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Only active users are shown. Users already assigned to this group can be selected safely; duplicate active memberships are not created.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: Key('assign${widget.kind.sectionTitle}Search'),
                controller: _searchController,
                enabled: !busy,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search ${widget.kind.lowerPlural}',
                  errorText: candidateState.searchErrorText,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: candidateController.updateSearchDraft,
                onSubmitted: (_) => candidateController.commitSearchNow(),
              ),
              if (actionState.formMessage != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(actionState.formMessage!),
                ),
              ],
              if (busy) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  label: 'Assigning ${widget.kind.lowerPlural}',
                  child: const LinearProgressIndicator(),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: _CandidateResults(
                  state: candidateState,
                  kind: widget.kind,
                  busy: busy,
                  onToggle: candidateController.toggleSelection,
                  onRetry: candidateController.retry,
                ),
              ),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: candidateState.canGoPrevious && !busy
                        ? candidateController.previousPage
                        : null,
                    child: const Text('Previous'),
                  ),
                  OutlinedButton(
                    onPressed: candidateState.canGoNext && !busy
                        ? candidateController.nextPage
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                label: 'Selected ${candidateState.selected.length} of 100',
                child: Text(
                  'Selected: ${candidateState.selected.length} / 100',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SizedBox(
                height: 120,
                child: candidateState.selected.isEmpty
                    ? const Text('No users selected')
                    : ListView.builder(
                        itemCount: candidateState.selected.length,
                        itemBuilder: (context, index) {
                          final user = candidateState.selected[index];
                          return ListTile(
                            dense: true,
                            title: Text(user.fullName),
                            subtitle: Text(user.loginName),
                            trailing: IconButton(
                              tooltip: 'Remove from selection',
                              onPressed: busy
                                  ? null
                                  : () => candidateController.removeSelected(
                                      user,
                                    ),
                              icon: const Icon(Icons.close),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: Key('assign${widget.kind.sectionTitle}Cancel'),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: Key('assign${widget.kind.sectionTitle}Submit'),
            onPressed: canSubmit ? actionController.submitAssignment : null,
            child: Text(widget.kind.assignTitle),
          ),
        ],
      ),
    );
  }

  void _closeStaleDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }
}

class _CandidateResults extends StatelessWidget {
  const _CandidateResults({
    required this.state,
    required this.kind,
    required this.busy,
    required this.onToggle,
    required this.onRetry,
  });

  final InstitutionGroupMembershipCandidateState state;
  final InstitutionGroupMemberKind kind;
  final bool busy;
  final void Function(InstitutionUser, bool) onToggle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.status == InstitutionGroupMembershipCandidateStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == InstitutionGroupMembershipCandidateStatus.error) {
      return Semantics(
        liveRegion: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Unable to load candidate users'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: state.isRetryInFlight ? null : onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (state.result?.users.isEmpty ?? true) {
      return const Center(child: Text('No matching active users'));
    }
    return ListView.builder(
      itemCount: state.result!.users.length,
      itemBuilder: (context, index) {
        final user = state.result!.users[index];
        final selected = state.isSelected(user);
        final maxReached = state.selected.length >= 100;
        return CheckboxListTile(
          key: Key('candidate-${kind.name}-${user.id}'),
          value: selected,
          onChanged: busy || (!selected && maxReached)
              ? null
              : (value) => onToggle(user, value ?? false),
          title: Text(user.fullName),
          subtitle: Text(user.loginName),
          controlAffinity: ListTileControlAffinity.leading,
        );
      },
    );
  }
}

class _MembershipRemoveDialog extends ConsumerWidget {
  const _MembershipRemoveDialog({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      institutionGroupMembershipActionControllerProvider(groupId),
    );
    final controller = ref.read(
      institutionGroupMembershipActionControllerProvider(groupId).notifier,
    );
    if (!state.isRemoveDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }
    final busy = state.isBusy;
    final membership = state.membership!;
    final kind = state.memberKind!;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        key: const Key('institutionGroupMembershipRemoveDialog'),
        title: Text('Remove ${kind.lowerSingular} from group?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(membership.fullName),
              Text(membership.loginName),
              const SizedBox(height: 16),
              const Text(
                'This ends the current group membership and revokes future group-based access. Historical relationship records and existing learning history are preserved. The user account itself is not deactivated.',
              ),
              if (busy) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  label: 'Removing ${kind.lowerSingular}',
                  child: const LinearProgressIndicator(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('institutionGroupMembershipRemoveCancel'),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('institutionGroupMembershipRemoveConfirm'),
            onPressed: busy ? null : controller.confirmRemove,
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
