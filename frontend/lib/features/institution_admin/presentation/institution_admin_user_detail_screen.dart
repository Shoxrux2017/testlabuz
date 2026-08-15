import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../application/institution_user_action_controller.dart';
import '../application/institution_user_action_state.dart';
import '../application/institution_user_detail_controller.dart';
import '../application/institution_user_detail_state.dart';
import '../domain/institution_user.dart';
import '../domain/institution_user_mutation.dart';
import 'institution_admin_user_formatters.dart';

const _detailPadding = 24.0;
const _detailMaxWidth = 960.0;

class InstitutionAdminUserDetailScreen extends ConsumerStatefulWidget {
  const InstitutionAdminUserDetailScreen({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<InstitutionAdminUserDetailScreen> createState() =>
      _InstitutionAdminUserDetailScreenState();
}

class _InstitutionAdminUserDetailScreenState
    extends ConsumerState<InstitutionAdminUserDetailScreen> {
  final _editFocusNode = FocusNode();
  final _lifecycleFocusNode = FocusNode();
  final _headingFocusNode = FocusNode();

  @override
  void dispose() {
    _editFocusNode.dispose();
    _lifecycleFocusNode.dispose();
    _headingFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    final state = ref.watch(institutionUserDetailControllerProvider(userId));
    final actionState = ref.watch(
      institutionUserActionControllerProvider(userId),
    );
    final controller = ref.read(
      institutionUserDetailControllerProvider(userId).notifier,
    );
    final actionController = ref.read(
      institutionUserActionControllerProvider(userId).notifier,
    );
    final canAct =
        state.status == InstitutionUserDetailStatus.data &&
        state.user != null &&
        !actionState.isBusy;

    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Semantics(
        key: const Key('institutionUserDetailSemanticsContainer'),
        container: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(_detailPadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _detailMaxWidth),
              child: _DetailContent(
                state: state,
                actionState: actionState,
                onBack: () => context.go(AppRoutePaths.institutionAdminUsers),
                onRefresh:
                    (state.status == InstitutionUserDetailStatus.data ||
                            state.status ==
                                InstitutionUserDetailStatus.refreshing) &&
                        !actionState.isBusy
                    ? controller.refresh
                    : null,
                onRetry:
                    state.status == InstitutionUserDetailStatus.error &&
                        state.isRetryable
                    ? controller.retry
                    : null,
                editFocusNode: _editFocusNode,
                lifecycleFocusNode: _lifecycleFocusNode,
                headingFocusNode: _headingFocusNode,
                showActions: state.status == InstitutionUserDetailStatus.data,
                onEdit: canAct
                    ? () => _openEditDialog(actionController, state.user!)
                    : null,
                onLifecycle: canAct
                    ? () => _openLifecycleDialog(actionController, state.user!)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditDialog(
    InstitutionUserActionController controller,
    InstitutionUser user,
  ) async {
    if (!controller.beginEdit(user)) {
      return;
    }
    final openedUserId = widget.userId;
    final focusKey = controller.focusKey!;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _UserEditDialog(userId: openedUserId),
    );
    if (!mounted || widget.userId != openedUserId) {
      return;
    }
    final current = ref.read(
      institutionUserActionControllerProvider(openedUserId),
    );
    if (!current.isBusy &&
        (current.isEditing ||
            current.status ==
                InstitutionUserActionStatus.lifecycleConfirming)) {
      controller.dismiss();
    }
    if (controller.canRestoreFocus(focusKey)) {
      _restoreActionFocus(_editFocusNode);
    }
  }

  Future<void> _openLifecycleDialog(
    InstitutionUserActionController controller,
    InstitutionUser user,
  ) async {
    if (!controller.beginLifecycle(user)) {
      return;
    }
    final openedUserId = widget.userId;
    final focusKey = controller.focusKey!;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _UserLifecycleDialog(userId: openedUserId),
    );
    if (!mounted || widget.userId != openedUserId) {
      return;
    }
    final current = ref.read(
      institutionUserActionControllerProvider(openedUserId),
    );
    if (!current.isBusy && current.isLifecycleDialog) {
      controller.dismiss();
    }
    if (controller.canRestoreFocus(focusKey)) {
      _restoreActionFocus(_lifecycleFocusNode);
    }
  }

  void _restoreActionFocus(FocusNode preferred) {
    final detail = ref.read(
      institutionUserDetailControllerProvider(widget.userId),
    );
    if (detail.status == InstitutionUserDetailStatus.data) {
      preferred.requestFocus();
    } else {
      _headingFocusNode.requestFocus();
    }
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.state,
    required this.actionState,
    required this.onBack,
    required this.onRefresh,
    required this.onRetry,
    required this.editFocusNode,
    required this.lifecycleFocusNode,
    required this.headingFocusNode,
    required this.onEdit,
    required this.onLifecycle,
    required this.showActions,
  });

  final InstitutionUserDetailState state;
  final InstitutionUserActionState actionState;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;
  final VoidCallback? onRetry;
  final FocusNode editFocusNode;
  final FocusNode lifecycleFocusNode;
  final FocusNode headingFocusNode;
  final VoidCallback? onEdit;
  final VoidCallback? onLifecycle;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    final isRefreshing = state.status == InstitutionUserDetailStatus.refreshing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailToolbar(
          user: user,
          isRefreshing: isRefreshing,
          onBack: onBack,
          onRefresh: onRefresh,
          editFocusNode: editFocusNode,
          lifecycleFocusNode: lifecycleFocusNode,
          headingFocusNode: headingFocusNode,
          onEdit: onEdit,
          onLifecycle: onLifecycle,
          showActions: showActions,
        ),
        if (actionState.feedback != null) ...[
          const SizedBox(height: 16),
          Semantics(
            key: const Key('institutionUserActionFeedback'),
            liveRegion: true,
            container: true,
            child: MaterialBanner(
              content: Text(actionState.feedback!),
              actions: const [SizedBox.shrink()],
            ),
          ),
        ],
        const SizedBox(height: 24),
        switch (state.status) {
          InstitutionUserDetailStatus.initial ||
          InstitutionUserDetailStatus.loading => const _LoadingState(),
          InstitutionUserDetailStatus.localUnavailableTarget ||
          InstitutionUserDetailStatus.notFound => _NotFoundState(
            onBack: onBack,
          ),
          InstitutionUserDetailStatus.error => _ErrorState(
            onBack: onBack,
            onRetry: onRetry,
          ),
          InstitutionUserDetailStatus.data ||
          InstitutionUserDetailStatus.refreshing => _UserDetails(user: user!),
        },
      ],
    );
  }
}

class _DetailToolbar extends StatelessWidget {
  const _DetailToolbar({
    required this.user,
    required this.isRefreshing,
    required this.onBack,
    required this.onRefresh,
    required this.editFocusNode,
    required this.lifecycleFocusNode,
    required this.headingFocusNode,
    required this.onEdit,
    required this.onLifecycle,
    required this.showActions,
  });

  final InstitutionUser? user;
  final bool isRefreshing;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;
  final FocusNode editFocusNode;
  final FocusNode lifecycleFocusNode;
  final FocusNode headingFocusNode;
  final VoidCallback? onEdit;
  final VoidCallback? onLifecycle;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final title = user?.fullName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Users'),
            ),
            if (onRefresh != null)
              Tooltip(
                message: isRefreshing ? 'Refreshing user details' : 'Refresh',
                child: OutlinedButton.icon(
                  key: const Key('institutionUserDetailRefresh'),
                  onPressed: isRefreshing ? null : onRefresh,
                  icon: isRefreshing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(isRefreshing ? 'Refreshing' : 'Refresh'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Focus(
            focusNode: headingFocusNode,
            skipTraversal: true,
            child: Text(
              'User details',
              key: const Key('institutionUserDetailHeading'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        if (title != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            title,
            key: const Key('institutionUserDetailName'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (showActions) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  key: const Key('institutionUserEditAction'),
                  focusNode: editFocusNode,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                FilledButton.tonalIcon(
                  key: const Key('institutionUserLifecycleAction'),
                  focusNode: lifecycleFocusNode,
                  onPressed: onLifecycle,
                  icon: Icon(
                    user!.isActive
                        ? Icons.person_off_outlined
                        : Icons.person_outline,
                  ),
                  label: Text(user!.isActive ? 'Deactivate' : 'Activate'),
                ),
              ],
            ),
          ],
        ],
        if (isRefreshing) ...[
          const SizedBox(height: 12),
          Semantics(
            key: const Key('institutionUserDetailRefreshAnnouncement'),
            liveRegion: true,
            label: 'Refreshing user details',
            child: LinearProgressIndicator(),
          ),
        ],
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading user details',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _MessageState(
      title: 'User unavailable',
      message: 'This user does not exist or is not available to your account.',
      onBack: onBack,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onBack, required this.onRetry});

  final VoidCallback onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _MessageState(
      title: 'Unable to load user details',
      message: 'User details could not be loaded safely.',
      onBack: onBack,
      onRetry: onRetry,
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.title,
    required this.message,
    required this.onBack,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onBack;
  final VoidCallback? onRetry;

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
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Users'),
                  ),
                  if (onRetry != null)
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
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

class _UserDetails extends StatelessWidget {
  const _UserDetails({required this.user});

  final InstitutionUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailSection(
          title: 'Identity',
          children: [
            _DetailField(label: 'Full name', value: user.fullName),
            _DetailField(label: 'Login name', value: user.loginName),
            _DetailField(
              label: 'Role',
              value: formatInstitutionUserRole(user.role),
              semanticLabel: 'Role ${formatInstitutionUserRole(user.role)}',
            ),
            _DetailField(
              label: 'User ID',
              value: user.id,
              selectable: true,
              excludeValueFromSemantics: true,
            ),
          ],
        ),
        _DetailSection(
          title: 'Contact',
          children: [
            _DetailField(label: 'Email', value: user.email ?? 'Not provided'),
            _DetailField(label: 'Phone', value: user.phone ?? 'Not provided'),
          ],
        ),
        _DetailSection(
          title: 'Account state',
          children: [
            _DetailField(
              label: 'Status',
              value: user.isActive ? 'Active' : 'Inactive',
              semanticLabel: 'Status ${user.isActive ? 'Active' : 'Inactive'}',
            ),
            _DetailField(
              label: 'First login',
              value: user.mustChangePassword
                  ? 'Password change required'
                  : 'Completed',
              semanticLabel: user.mustChangePassword
                  ? 'First login password change required'
                  : 'First login completed',
            ),
          ],
        ),
        _DetailSection(
          title: 'Activity and lifecycle',
          children: [
            _DetailField(
              label: 'Last login',
              value: user.lastLoginAt == null
                  ? 'Never'
                  : formatInstitutionUserUtc(user.lastLoginAt!),
            ),
            _DetailField(
              label: 'Deactivated',
              value: user.deactivatedAt == null
                  ? 'Not deactivated'
                  : formatInstitutionUserUtc(user.deactivatedAt!),
            ),
            _DetailField(
              label: 'Created',
              value: formatInstitutionUserUtc(user.createdAt),
            ),
            _DetailField(
              label: 'Updated',
              value: formatInstitutionUserUtc(user.updatedAt),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    this.selectable = false,
    this.semanticLabel,
    this.excludeValueFromSemantics = false,
  });

  final String label;
  final String value;
  final bool selectable;
  final String? semanticLabel;
  final bool excludeValueFromSemantics;

  @override
  Widget build(BuildContext context) {
    final displayedValue = selectable
        ? SelectableText(value, key: Key('institutionUserDetailValue$label'))
        : Text(value, key: Key('institutionUserDetailValue$label'));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        label: semanticLabel,
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            if (excludeValueFromSemantics)
              ExcludeSemantics(child: displayedValue)
            else
              displayedValue,
          ],
        ),
      ),
    );
  }
}

class _UserEditDialog extends ConsumerStatefulWidget {
  const _UserEditDialog({required this.userId});

  final String userId;

  @override
  ConsumerState<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends ConsumerState<_UserEditDialog> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final _fullNameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _formFeedbackFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final form = ref
        .read(institutionUserActionControllerProvider(widget.userId))
        .form!;
    _fullNameController = TextEditingController(text: form.fullName);
    _emailController = TextEditingController(text: form.email);
    _phoneController = TextEditingController(text: form.phone);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _fullNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _formFeedbackFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      institutionUserActionControllerProvider(widget.userId),
    );
    final controller = ref.read(
      institutionUserActionControllerProvider(widget.userId).notifier,
    );
    final busy = state.isBusy;
    if (!state.isEditing && !busy) {
      _closeStaleDialog();
    }
    _scheduleErrorFocus(state);

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        key: const Key('institutionUserEditDialog'),
        title: const Text('Edit user'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('institutionUserEditFullName'),
                  controller: _fullNameController,
                  focusNode: _fullNameFocusNode,
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Full name *',
                    errorText: state.errorFor(
                      InstitutionUserEditField.fullName,
                    ),
                  ),
                  onChanged: controller.updateFullName,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('institutionUserEditEmail'),
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    errorText: state.errorFor(InstitutionUserEditField.email),
                  ),
                  onChanged: controller.updateEmail,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('institutionUserEditPhone'),
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  enabled: !busy,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    errorText: state.errorFor(InstitutionUserEditField.phone),
                  ),
                  onChanged: controller.updatePhone,
                  onSubmitted: busy ? null : (_) => _submit(controller),
                ),
                if (state.formMessage != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    key: const Key('institutionUserEditFormFeedback'),
                    liveRegion: true,
                    container: true,
                    child: Focus(
                      key: const Key('institutionUserEditFormFeedbackFocus'),
                      focusNode: _formFeedbackFocusNode,
                      child: Text(state.formMessage!),
                    ),
                  ),
                ],
                if (busy) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    label:
                        state.status ==
                            InstitutionUserActionStatus.reconcilingCurrentState
                        ? 'Checking current server state'
                        : 'Saving user changes',
                    child: const LinearProgressIndicator(),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () {
                    controller.dismiss();
                    Navigator.of(context).pop();
                  },
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('institutionUserEditSubmit'),
            onPressed: busy ? null : () => _submit(controller),
            child: Text(busy ? 'Saving…' : 'Save changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(InstitutionUserActionController controller) async {
    await controller.submitEdit();
  }

  void _scheduleErrorFocus(InstitutionUserActionState state) {
    if (state.status != InstitutionUserActionStatus.validationFailure &&
        state.formMessage == null) {
      return;
    }
    final firstInvalidField = InstitutionUserEditField.values
        .where(state.fieldErrors.containsKey)
        .firstOrNull;
    final node = switch (firstInvalidField) {
      InstitutionUserEditField.fullName => _fullNameFocusNode,
      InstitutionUserEditField.email => _emailFocusNode,
      InstitutionUserEditField.phone => _phoneFocusNode,
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

class _UserLifecycleDialog extends ConsumerWidget {
  const _UserLifecycleDialog({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(institutionUserActionControllerProvider(userId));
    final controller = ref.read(
      institutionUserActionControllerProvider(userId).notifier,
    );
    if (!state.isLifecycleDialog && !state.isBusy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }
    final selected = state.selected!;
    final action = state.lifecycleAction!;
    final activating = action == InstitutionUserLifecycleAction.activate;
    final busy = state.isBusy;

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        key: const Key('institutionUserLifecycleDialog'),
        title: Text(activating ? 'Activate user' : 'Deactivate user'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${selected.fullName} (${selected.loginName})'),
                const SizedBox(height: 12),
                Text(
                  activating
                      ? 'Activation changes only this account’s active state. It does not reset a password, clear first-login requirements, create a session, change the role, or bypass an inactive institution. Normal sign-in and authorization requirements continue to apply.'
                      : 'Deactivation blocks this account’s normal login and protected access. Credentials, institution binding, relationships, and history are not deleted. This does not deactivate the institution or another user.',
                ),
                if (state.formMessage != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    container: true,
                    child: Text(state.formMessage!),
                  ),
                ],
                if (busy) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    label:
                        state.status ==
                            InstitutionUserActionStatus.reconcilingCurrentState
                        ? 'Checking current server state'
                        : activating
                        ? 'Activating user'
                        : 'Deactivating user',
                    child: const LinearProgressIndicator(),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () {
                    controller.dismiss();
                    Navigator.of(context).pop();
                  },
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('institutionUserLifecycleConfirm'),
            onPressed: busy
                ? null
                : () async {
                    await controller.confirmLifecycle();
                  },
            child: Text(
              busy
                  ? activating
                        ? 'Activating…'
                        : 'Deactivating…'
                  : activating
                  ? 'Activate user'
                  : 'Deactivate user',
            ),
          ),
        ],
      ),
    );
  }
}
