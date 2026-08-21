import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../application/institution_group_detail_controller.dart';
import '../application/institution_group_detail_state.dart';
import '../domain/institution_group.dart';
import 'institution_admin_group_formatters.dart';

const _detailPadding = 24.0;
const _detailMaxWidth = 960.0;

class InstitutionAdminGroupDetailScreen extends ConsumerWidget {
  const InstitutionAdminGroupDetailScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(institutionGroupDetailControllerProvider(groupId));
    final controller = ref.read(
      institutionGroupDetailControllerProvider(groupId).notifier,
    );
    final isRefreshing =
        state.status == InstitutionGroupDetailStatus.refreshing;

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
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('institutionGroupDetailBackButton'),
                        onPressed: () => context.goNamed(
                          AppRouteNames.institutionAdminGroups,
                        ),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to Groups'),
                      ),
                      if (state.status == InstitutionGroupDetailStatus.data ||
                          isRefreshing)
                        OutlinedButton.icon(
                          key: const Key('institutionGroupDetailRefreshButton'),
                          onPressed: isRefreshing ? null : controller.refresh,
                          icon: isRefreshing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(isRefreshing ? 'Refreshing' : 'Refresh'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      'Group Details',
                      key: const Key('institutionGroupDetailHeading'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (state.group case final group?) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      group.name,
                      key: const Key('institutionGroupDetailName'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                  if (isRefreshing) ...[
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
                  switch (state.status) {
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
                      action: state.isRetryable
                          ? FilledButton.icon(
                              key: const Key(
                                'institutionGroupDetailRetryButton',
                              ),
                              onPressed: controller.retry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            )
                          : null,
                    ),
                    InstitutionGroupDetailStatus.data ||
                    InstitutionGroupDetailStatus.refreshing => _GroupDetails(
                      group: state.group!,
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
    return Card(
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
