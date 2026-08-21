import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../application/institution_group_action_controller.dart';
import '../application/institution_group_action_state.dart';
import '../application/institution_group_detail_controller.dart';
import '../application/institution_group_detail_state.dart';
import '../domain/institution_group.dart';
import '../domain/institution_group_mutation.dart';
import 'institution_admin_group_formatters.dart';

const _detailPadding = 24.0;
const _detailMaxWidth = 960.0;

class InstitutionAdminGroupDetailScreen extends ConsumerStatefulWidget {
  const InstitutionAdminGroupDetailScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<InstitutionAdminGroupDetailScreen> createState() =>
      _InstitutionAdminGroupDetailScreenState();
}

class _InstitutionAdminGroupDetailScreenState
    extends ConsumerState<InstitutionAdminGroupDetailScreen> {
  final _editFocusNode = FocusNode();
  final _archiveFocusNode = FocusNode();
  final _headingFocusNode = FocusNode();

  @override
  void dispose() {
    _editFocusNode.dispose();
    _archiveFocusNode.dispose();
    _headingFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupId = widget.groupId;
    final detailState = ref.watch(
      institutionGroupDetailControllerProvider(groupId),
    );
    final actionState = ref.watch(
      institutionGroupActionControllerProvider(groupId),
    );
    final detailController = ref.read(
      institutionGroupDetailControllerProvider(groupId).notifier,
    );
    final actionController = ref.read(
      institutionGroupActionControllerProvider(groupId).notifier,
    );
    final isRefreshing =
        detailState.status == InstitutionGroupDetailStatus.refreshing;
    final activeGroup = detailState.status == InstitutionGroupDetailStatus.data
        ? detailState.group
        : null;
    final canAct =
        activeGroup?.status == InstitutionGroupStatus.active &&
        !actionState.hasOpenAction;

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Semantics(
        key: const Key('institutionAdminGroupDetailScreen'),
        container: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(_detailPadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _detailMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DetailToolbar(
                    detailState: detailState,
                    editFocusNode: _editFocusNode,
                    archiveFocusNode: _archiveFocusNode,
                    onBack: () =>
                        context.goNamed(AppRouteNames.institutionAdminGroups),
                    onRefresh:
                        detailState.status ==
                                InstitutionGroupDetailStatus.data &&
                            !actionState.hasOpenAction
                        ? detailController.refresh
                        : null,
                    onEdit: canAct
                        ? () => _openEditDialog(actionController, activeGroup!)
                        : null,
                    onArchive: canAct
                        ? () =>
                              _openArchiveDialog(actionController, activeGroup!)
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Focus(
                      focusNode: _headingFocusNode,
                      skipTraversal: true,
                      child: Text(
                        'Group Details',
                        key: const Key('institutionGroupDetailHeading'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  if (detailState.group case final group?) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      group.name,
                      key: const Key('institutionGroupDetailName'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                  if (actionState.feedback != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      key: const Key('institutionGroupActionFeedback'),
                      liveRegion: true,
                      container: true,
                      child: MaterialBanner(
                        content: Text(actionState.feedback!),
                        actions: const [SizedBox.shrink()],
                      ),
                    ),
                  ],
                  if (actionState.isReconciling) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      key: const Key('institutionGroupReconciliationStatus'),
                      liveRegion: true,
                      label: 'Checking current server state',
                      child: const LinearProgressIndicator(),
                    ),
                  ] else if (isRefreshing) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      label: 'Refreshing group',
                      child: const LinearProgressIndicator(
                        key: Key('institutionGroupDetailRefreshing'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  switch (detailState.status) {
                    InstitutionGroupDetailStatus.initial ||
                    InstitutionGroupDetailStatus.loading =>
                      const _GroupDetailLoading(),
                    InstitutionGroupDetailStatus.localUnavailableTarget ||
                    InstitutionGroupDetailStatus.notFound =>
                      const _GroupDetailMessage(
                        key: Key('institutionGroupDetailNotFound'),
                        title: 'Group not found',
                        message: 'The requested group is not available.',
                      ),
                    InstitutionGroupDetailStatus.error => _GroupDetailMessage(
                      key: const Key('institutionGroupDetailError'),
                      title: 'Unable to load group details',
                      message: 'Group details could not be loaded safely.',
                      action: detailState.isRetryable
                          ? FilledButton.icon(
                              key: const Key(
                                'institutionGroupDetailRetryButton',
                              ),
                              onPressed: detailController.retry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            )
                          : null,
                    ),
                    InstitutionGroupDetailStatus.data ||
                    InstitutionGroupDetailStatus.refreshing => _GroupDetails(
                      group: detailState.group!,
                    ),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditDialog(
    InstitutionGroupActionController controller,
    InstitutionGroup group,
  ) async {
    if (!controller.beginEdit(group)) {
      return;
    }
    final openedGroupId = widget.groupId;
    final focusKey = controller.focusKey!;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _GroupEditDialog(groupId: openedGroupId),
    );
    if (!mounted || widget.groupId != openedGroupId) {
      return;
    }
    final current = ref.read(
      institutionGroupActionControllerProvider(openedGroupId),
    );
    if (!current.isBusy && current.isEditing) {
      controller.dismiss();
    }
    _restoreFocusAfterDialog(controller, focusKey, _editFocusNode);
  }

  Future<void> _openArchiveDialog(
    InstitutionGroupActionController controller,
    InstitutionGroup group,
  ) async {
    if (!controller.beginArchive(group)) {
      return;
    }
    final openedGroupId = widget.groupId;
    final focusKey = controller.focusKey!;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _GroupArchiveDialog(groupId: openedGroupId),
    );
    if (!mounted || widget.groupId != openedGroupId) {
      return;
    }
    final current = ref.read(
      institutionGroupActionControllerProvider(openedGroupId),
    );
    if (!current.isBusy && current.isArchiveDialog) {
      controller.dismiss();
    }
    _restoreFocusAfterDialog(controller, focusKey, _archiveFocusNode);
  }

  void _restoreFocusAfterDialog(
    InstitutionGroupActionController controller,
    InstitutionGroupActionFocusKey focusKey,
    FocusNode actionNode,
  ) {
    if (controller.canRestoreFocus(focusKey)) {
      actionNode.requestFocus();
      return;
    }
    final detail = ref.read(
      institutionGroupDetailControllerProvider(widget.groupId),
    );
    if (detail.status == InstitutionGroupDetailStatus.data &&
        detail.group?.status == InstitutionGroupStatus.archived) {
      _headingFocusNode.requestFocus();
    }
  }
}

class _DetailToolbar extends StatelessWidget {
  const _DetailToolbar({
    required this.detailState,
    required this.editFocusNode,
    required this.archiveFocusNode,
    required this.onBack,
    required this.onRefresh,
    required this.onEdit,
    required this.onArchive,
  });

  final InstitutionGroupDetailState detailState;
  final FocusNode editFocusNode;
  final FocusNode archiveFocusNode;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final group = detailState.group;
    final showActiveActions =
        detailState.status == InstitutionGroupDetailStatus.data &&
        group?.status == InstitutionGroupStatus.active;
    final showRefresh =
        detailState.status == InstitutionGroupDetailStatus.data ||
        detailState.status == InstitutionGroupDetailStatus.refreshing;
    final isRefreshing =
        detailState.status == InstitutionGroupDetailStatus.refreshing;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          key: const Key('institutionGroupDetailBackButton'),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Groups'),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (showRefresh)
              OutlinedButton.icon(
                key: const Key('institutionGroupDetailRefreshButton'),
                onPressed: onRefresh,
                icon: isRefreshing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(isRefreshing ? 'Refreshing' : 'Refresh'),
              ),
            if (showActiveActions) ...[
              OutlinedButton.icon(
                key: const Key('institutionGroupEditAction'),
                focusNode: editFocusNode,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              FilledButton.tonalIcon(
                key: const Key('institutionGroupArchiveAction'),
                focusNode: archiveFocusNode,
                onPressed: onArchive,
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive Group'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _GroupEditDialog extends ConsumerStatefulWidget {
  const _GroupEditDialog({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_GroupEditDialog> createState() => _GroupEditDialogState();
}

class _GroupEditDialogState extends ConsumerState<_GroupEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _levelController;
  late final TextEditingController _subjectController;
  late final TextEditingController _descriptionController;
  final _nameFocusNode = FocusNode();
  final _levelFocusNode = FocusNode();
  final _subjectFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _formFeedbackFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final form = ref
        .read(institutionGroupActionControllerProvider(widget.groupId))
        .form!;
    _nameController = TextEditingController(text: form.name);
    _levelController = TextEditingController(text: form.level);
    _subjectController = TextEditingController(text: form.subjectDirection);
    _descriptionController = TextEditingController(text: form.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _levelController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    _levelFocusNode.dispose();
    _subjectFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _formFeedbackFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      institutionGroupActionControllerProvider(widget.groupId),
    );
    final controller = ref.read(
      institutionGroupActionControllerProvider(widget.groupId).notifier,
    );
    final busy = state.isBusy;
    if (!state.isEditing) {
      _closeStaleDialog();
      return const SizedBox.shrink();
    }
    _scheduleErrorFocus(state);

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        key: const Key('institutionGroupEditDialog'),
        title: const Text('Edit Group'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('institutionGroupEditName'),
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Name *',
                    errorText: state.errorFor(InstitutionGroupEditField.name),
                  ),
                  onChanged: controller.updateName,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('institutionGroupEditLevel'),
                  controller: _levelController,
                  focusNode: _levelFocusNode,
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Level',
                    errorText: state.errorFor(InstitutionGroupEditField.level),
                  ),
                  onChanged: controller.updateLevel,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('institutionGroupEditSubjectDirection'),
                  controller: _subjectController,
                  focusNode: _subjectFocusNode,
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Subject direction',
                    errorText: state.errorFor(
                      InstitutionGroupEditField.subjectDirection,
                    ),
                  ),
                  onChanged: controller.updateSubjectDirection,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('institutionGroupEditDescription'),
                  controller: _descriptionController,
                  focusNode: _descriptionFocusNode,
                  enabled: !busy,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    errorText: state.errorFor(
                      InstitutionGroupEditField.description,
                    ),
                  ),
                  onChanged: controller.updateDescription,
                ),
                if (state.formMessage != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    key: const Key('institutionGroupEditFormFeedback'),
                    liveRegion: true,
                    container: true,
                    child: Focus(
                      focusNode: _formFeedbackFocusNode,
                      child: Text(state.formMessage!),
                    ),
                  ),
                ],
                if (busy) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    label: state.isReconciling
                        ? 'Checking current server state'
                        : 'Saving group',
                    child: const LinearProgressIndicator(),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('institutionGroupEditCancel'),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('institutionGroupEditSave'),
            onPressed: busy ? null : controller.submitEdit,
            child: Text(busy ? 'Saving…' : 'Save changes'),
          ),
        ],
      ),
    );
  }

  void _scheduleErrorFocus(InstitutionGroupActionState state) {
    if (state.isBusy ||
        (state.status != InstitutionGroupActionStatus.validationFailure &&
            state.formMessage == null)) {
      return;
    }
    final firstInvalid = InstitutionGroupEditField.values
        .where(state.fieldErrors.containsKey)
        .firstOrNull;
    final node = switch (firstInvalid) {
      InstitutionGroupEditField.name => _nameFocusNode,
      InstitutionGroupEditField.level => _levelFocusNode,
      InstitutionGroupEditField.subjectDirection => _subjectFocusNode,
      InstitutionGroupEditField.description => _descriptionFocusNode,
      null => _formFeedbackFocusNode,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        node.requestFocus();
      }
    });
  }

  void _closeStaleDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }
}

class _GroupArchiveDialog extends ConsumerWidget {
  const _GroupArchiveDialog({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(institutionGroupActionControllerProvider(groupId));
    final controller = ref.read(
      institutionGroupActionControllerProvider(groupId).notifier,
    );
    final busy = state.isBusy;
    if (!state.isArchiveDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        key: const Key('institutionGroupArchiveDialog'),
        title: const Text('Archive group?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(state.selected!.name),
              const SizedBox(height: 16),
              const Text(
                'Archiving makes this group read-only for future management. Historical relationships and learning records are preserved. Groups cannot be reactivated in the current MVP.',
              ),
              if (busy) ...[
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  label: state.isReconciling
                      ? 'Checking current server state'
                      : 'Archiving group',
                  child: const LinearProgressIndicator(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('institutionGroupArchiveCancel'),
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('institutionGroupArchiveConfirm'),
            onPressed: busy ? null : controller.confirmArchive,
            child: Text(busy ? 'Archiving…' : 'Archive Group'),
          ),
        ],
      ),
    );
  }
}

class _GroupDetailLoading extends StatelessWidget {
  const _GroupDetailLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading group',
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _GroupDetailMessage extends StatelessWidget {
  const _GroupDetailMessage({
    required super.key,
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(message),
              if (action != null) ...[
                const SizedBox(height: 24),
                Align(alignment: Alignment.centerLeft, child: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupDetails extends StatelessWidget {
  const _GroupDetails({required this.group});

  final InstitutionGroup group;

  @override
  Widget build(BuildContext context) {
    final status = group.status == InstitutionGroupStatus.active
        ? 'Active'
        : 'Archived';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (group.status == InstitutionGroupStatus.archived) ...[
          Semantics(
            key: const Key('institutionGroupArchivedReadOnly'),
            liveRegion: true,
            container: true,
            child: const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Archived groups are read-only.'),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Card(
          key: const Key('institutionGroupDetailData'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 24,
              runSpacing: 20,
              children: [
                _GroupDetailField(label: 'Name', value: group.name),
                _GroupDetailField(
                  label: 'Status',
                  value: status,
                  semanticLabel: 'Status $status',
                ),
                _GroupDetailField(
                  label: 'Level',
                  value: group.level ?? 'Not provided',
                ),
                _GroupDetailField(
                  label: 'Subject direction',
                  value: group.subjectDirection ?? 'Not provided',
                ),
                _GroupDetailField(
                  label: 'Description',
                  value: group.description ?? 'Not provided',
                ),
                _GroupDetailField(
                  label: 'Teachers',
                  value: group.teachersCount.toString(),
                ),
                _GroupDetailField(
                  label: 'Students',
                  value: group.studentsCount.toString(),
                ),
                _GroupDetailField(
                  label: 'Archived at',
                  value: group.archivedAt == null
                      ? '—'
                      : formatInstitutionGroupUtc(group.archivedAt!),
                ),
                _GroupDetailField(
                  label: 'Created',
                  value: formatInstitutionGroupUtc(group.createdAt),
                ),
                _GroupDetailField(
                  label: 'Updated',
                  value: formatInstitutionGroupUtc(group.updatedAt),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupDetailField extends StatelessWidget {
  const _GroupDetailField({
    required this.label,
    required this.value,
    this.semanticLabel,
  });

  final String label;
  final String value;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Semantics(
        label: semanticLabel ?? '$label: $value',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SelectableText(value),
          ],
        ),
      ),
    );
  }
}
