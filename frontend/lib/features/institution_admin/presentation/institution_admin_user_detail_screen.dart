import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../application/institution_user_detail_controller.dart';
import '../application/institution_user_detail_state.dart';
import '../domain/institution_user.dart';
import 'institution_admin_user_formatters.dart';

const _detailPadding = 24.0;
const _detailMaxWidth = 960.0;

class InstitutionAdminUserDetailScreen extends ConsumerWidget {
  const InstitutionAdminUserDetailScreen({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(institutionUserDetailControllerProvider(userId));
    final controller = ref.read(
      institutionUserDetailControllerProvider(userId).notifier,
    );

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
                onBack: () => context.go(AppRoutePaths.institutionAdminUsers),
                onRefresh:
                    state.status == InstitutionUserDetailStatus.data ||
                        state.status == InstitutionUserDetailStatus.refreshing
                    ? controller.refresh
                    : null,
                onRetry:
                    state.status == InstitutionUserDetailStatus.error &&
                        state.isRetryable
                    ? controller.retry
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.state,
    required this.onBack,
    required this.onRefresh,
    required this.onRetry,
  });

  final InstitutionUserDetailState state;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;
  final VoidCallback? onRetry;

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
        ),
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
  });

  final InstitutionUser? user;
  final bool isRefreshing;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;

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
          child: Text(
            'User details',
            key: const Key('institutionUserDetailHeading'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        if (title != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            title,
            key: const Key('institutionUserDetailName'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
            _DetailField(label: 'User ID', value: user.id, selectable: true),
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
  });

  final String label;
  final String value;
  final bool selectable;
  final String? semanticLabel;

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
            displayedValue,
          ],
        ),
      ),
    );
  }
}
