import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../application/platform_dashboard_controller.dart';
import '../application/platform_dashboard_state.dart';
import '../domain/platform_dashboard.dart';
import 'platform_dashboard_formatters.dart';

const _dashboardSpacing = 24.0;
const _sectionSpacing = 32.0;
const _tileSpacing = 16.0;
const _cardRadius = 8.0;
const _kpiMinWidth = 180.0;
const _kpiMaxWidth = 280.0;

class PlatformOwnerDashboardScreen extends ConsumerWidget {
  const PlatformOwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(platformDashboardControllerProvider);

    return switch (state.status) {
      PlatformDashboardStatus.initial ||
      PlatformDashboardStatus.loading => const _PlatformDashboardLoading(),
      PlatformDashboardStatus.data => _PlatformDashboardDataView(
        dashboard: state.dashboard!,
      ),
      PlatformDashboardStatus.error => _PlatformDashboardErrorView(
        failure: state.failure!,
        isRetryInFlight: state.isRetryInFlight,
        onRetry: () {
          ref.read(platformDashboardControllerProvider.notifier).retry();
        },
      ),
    };
  }
}

class _PlatformDashboardLoading extends StatelessWidget {
  const _PlatformDashboardLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('platformDashboardLoading'),
      child: Semantics(
        label: 'Loading platform dashboard',
        liveRegion: true,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _PlatformDashboardDataView extends StatelessWidget {
  const _PlatformDashboardDataView({required this.dashboard});

  final PlatformDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final isInstitutionEmpty = dashboard.isInstitutionEmpty;

    return SingleChildScrollView(
      key: Key(
        isInstitutionEmpty
            ? 'platformDashboardInstitutionEmpty'
            : 'platformDashboardData',
      ),
      padding: const EdgeInsets.all(_dashboardSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Platform Dashboard',
            key: const Key('platformDashboardHeading'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (isInstitutionEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No platform institutions exist yet.',
              key: const Key('platformDashboardInstitutionEmptyMessage'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: _dashboardSpacing),
          _KpiGrid(dashboard: dashboard),
          const SizedBox(height: _sectionSpacing),
          _RecentInstitutionsSection(
            institutions: dashboard.recentInstitutions,
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.dashboard});

  final PlatformDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _KpiMetric(
        label: 'Total institutions',
        value: dashboard.institutions.total,
        icon: Icons.account_balance_outlined,
      ),
      _KpiMetric(
        label: 'Active institutions',
        value: dashboard.institutions.active,
        icon: Icons.check_circle_outline,
      ),
      _KpiMetric(
        label: 'Inactive institutions',
        value: dashboard.institutions.inactive,
        icon: Icons.pause_circle_outline,
      ),
      _KpiMetric(
        label: 'Total users',
        value: dashboard.users.total,
        icon: Icons.groups_outlined,
      ),
      _KpiMetric(
        label: 'Active users',
        value: dashboard.users.active,
        icon: Icons.person_pin_circle_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = _tileWidthFor(constraints.maxWidth);

        return Wrap(
          key: const Key('platformDashboardKpis'),
          spacing: _tileSpacing,
          runSpacing: _tileSpacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: tileWidth,
                child: _KpiTile(metric: metric),
              ),
          ],
        );
      },
    );
  }

  double _tileWidthFor(double maxWidth) {
    if (maxWidth <= _kpiMinWidth) {
      return maxWidth;
    }

    final desiredColumns = maxWidth >= 1160
        ? 5
        : maxWidth >= 760
        ? 3
        : maxWidth >= 440
        ? 2
        : 1;
    final width =
        (maxWidth - (_tileSpacing * (desiredColumns - 1))) / desiredColumns;

    return width.clamp(_kpiMinWidth, _kpiMaxWidth);
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.metric});

  final _KpiMetric metric;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: Key('platformDashboardKpi${metric.label}'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(metric.icon, color: colorScheme.primary),
            const SizedBox(height: 18),
            Text(
              metric.value.toString(),
              key: Key('platformDashboardKpi${metric.label}Value'),
              style: Theme.of(context).textTheme.headlineMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              metric.label,
              key: Key('platformDashboardKpi${metric.label}Label'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentInstitutionsSection extends StatelessWidget {
  const _RecentInstitutionsSection({required this.institutions});

  final List<RecentPlatformInstitution> institutions;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('platformDashboardRecentInstitutions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Recent institutions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (institutions.isEmpty)
          const Text(
            'No recent institutions',
            key: Key('platformDashboardRecentEmpty'),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(_cardRadius),
            ),
            child: Column(
              children: [
                for (var index = 0; index < institutions.length; index++) ...[
                  _RecentInstitutionRow(
                    institution: institutions[index],
                    index: index,
                  ),
                  if (index < institutions.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _RecentInstitutionRow extends StatelessWidget {
  const _RecentInstitutionRow({required this.institution, required this.index});

  final RecentPlatformInstitution institution;
  final int index;

  @override
  Widget build(BuildContext context) {
    final statusLabel = platformInstitutionStatusLabel(institution.status);
    final statusColor = switch (institution.status) {
      PlatformInstitutionStatus.active => Theme.of(context).colorScheme.primary,
      PlatformInstitutionStatus.inactive => Theme.of(context).colorScheme.error,
    };

    return Padding(
      key: Key('platformDashboardRecentRow$index'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RecentNameAndType(institution: institution),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusBadge(label: statusLabel, color: statusColor),
                    Text(
                      formatPlatformDashboardUtcTimestamp(
                        institution.createdAt,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: _RecentNameAndType(institution: institution),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Text(
                  formatPlatformDashboardUtcTimestamp(institution.createdAt),
                ),
              ),
              const SizedBox(width: 16),
              _StatusBadge(label: statusLabel, color: statusColor),
            ],
          );
        },
      ),
    );
  }
}

class _RecentNameAndType extends StatelessWidget {
  const _RecentNameAndType({required this.institution});

  final RecentPlatformInstitution institution;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          institution.name,
          style: Theme.of(context).textTheme.titleMedium,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(platformInstitutionTypeLabel(institution.type)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Institution status: $label',
      child: Chip(
        avatar: Icon(Icons.circle, size: 10, color: color),
        label: Text(label),
      ),
    );
  }
}

class _PlatformDashboardErrorView extends StatelessWidget {
  const _PlatformDashboardErrorView({
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
      key: const Key('platformDashboardError'),
      child: Padding(
        padding: const EdgeInsets.all(_dashboardSpacing),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
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
                'Dashboard unavailable',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _dashboardFailureMessage(failure),
                key: const Key('platformDashboardErrorMessage'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('platformDashboardRetryButton'),
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

String _dashboardFailureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.authenticationRequired => 'Please sign in again.',
    ApiErrorCodes.passwordChangeRequired =>
      'Password change is required before dashboard access.',
    ApiErrorCodes.userInactive => 'This account is inactive.',
    ApiErrorCodes.institutionInactive => 'This institution is inactive.',
    ApiErrorCodes.forbidden =>
      'You do not have permission to view this dashboard.',
    ApiErrorCodes.validationFailed =>
      'The dashboard request did not match the API contract.',
    _ => switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The dashboard request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected dashboard response.',
      ApiFailureKind.cancelled => 'The dashboard request was cancelled.',
      ApiFailureKind.unknown ||
      ApiFailureKind.server ||
      ApiFailureKind.validation => 'The dashboard could not be loaded.',
    },
  };
}

class _KpiMetric {
  const _KpiMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;
}
