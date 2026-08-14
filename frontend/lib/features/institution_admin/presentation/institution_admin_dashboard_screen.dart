import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../application/institution_dashboard_controller.dart';
import '../application/institution_dashboard_state.dart';
import '../domain/institution_dashboard.dart';

const _dashboardSpacing = 24.0;
const _cardSpacing = 16.0;
const _cardRadius = 8.0;
const _cardMinWidth = 180.0;
const _cardMaxWidth = 320.0;

class InstitutionAdminDashboardScreen extends ConsumerWidget {
  const InstitutionAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return const SizedBox.shrink();
    }

    final state = ref.watch(institutionDashboardControllerProvider);

    return switch (state.status) {
      InstitutionDashboardStatus.initial ||
      InstitutionDashboardStatus.loading =>
        const _InstitutionDashboardLoading(),
      InstitutionDashboardStatus.data => _InstitutionDashboardDataView(
        dashboard: state.dashboard!,
        onRefresh: () {
          ref.read(institutionDashboardControllerProvider.notifier).refresh();
        },
      ),
      InstitutionDashboardStatus.error => _InstitutionDashboardErrorView(
        failure: state.failure!,
        isRetryInFlight: state.isRetryInFlight,
        onRetry: () {
          ref.read(institutionDashboardControllerProvider.notifier).retry();
        },
      ),
    };
  }
}

class _InstitutionDashboardLoading extends StatelessWidget {
  const _InstitutionDashboardLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('institutionDashboardLoading'),
      child: Semantics(
        label: 'Loading institution dashboard',
        liveRegion: true,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _InstitutionDashboardDataView extends StatelessWidget {
  const _InstitutionDashboardDataView({
    required this.dashboard,
    required this.onRefresh,
  });

  final InstitutionDashboard dashboard;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('institutionDashboardData'),
      padding: const EdgeInsets.all(_dashboardSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: _cardSpacing,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Institution Dashboard',
                  key: const Key('institutionDashboardHeading'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              OutlinedButton.icon(
                key: const Key('institutionDashboardRefreshButton'),
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: _dashboardSpacing),
          _InstitutionDashboardCardGrid(dashboard: dashboard),
          if (dashboard.hasNoUsers) ...[
            const SizedBox(height: _dashboardSpacing),
            Text(
              'No users yet.',
              key: const Key('institutionDashboardEmpty'),
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _InstitutionDashboardCardGrid extends StatelessWidget {
  const _InstitutionDashboardCardGrid({required this.dashboard});

  final InstitutionDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _InstitutionDashboardCardData(
        key: const Key('institutionDashboardTeachersCard'),
        valueKey: const Key('institutionDashboardTeachersValue'),
        title: 'Teachers',
        value: dashboard.teachers,
      ),
      _InstitutionDashboardCardData(
        key: const Key('institutionDashboardStudentsCard'),
        valueKey: const Key('institutionDashboardStudentsValue'),
        title: 'Students',
        value: dashboard.students,
      ),
      _InstitutionDashboardCardData(
        key: const Key('institutionDashboardParentsCard'),
        valueKey: const Key('institutionDashboardParentsValue'),
        title: 'Parents',
        value: dashboard.parents,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = _cardWidthFor(constraints.maxWidth);

        return Wrap(
          spacing: _cardSpacing,
          runSpacing: _cardSpacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: _InstitutionDashboardSummaryCard(data: card),
              ),
          ],
        );
      },
    );
  }

  double _cardWidthFor(double maxWidth) {
    if (maxWidth <= _cardMinWidth) {
      return maxWidth;
    }

    final columns = maxWidth >= 960
        ? 3
        : maxWidth >= 560
        ? 2
        : 1;
    final width = (maxWidth - (_cardSpacing * (columns - 1))) / columns;

    return width.clamp(_cardMinWidth, _cardMaxWidth);
  }
}

class _InstitutionDashboardSummaryCard extends StatelessWidget {
  const _InstitutionDashboardSummaryCard({required this.data});

  final _InstitutionDashboardCardData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: data.key,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(data.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Text(
              data.value.toString(),
              key: data.valueKey,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Total accounts',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _InstitutionDashboardErrorView extends StatelessWidget {
  const _InstitutionDashboardErrorView({
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
      key: const Key('institutionDashboardError'),
      child: SingleChildScrollView(
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
                key: const Key('institutionDashboardErrorMessage'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('institutionDashboardRetryButton'),
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

class _InstitutionDashboardCardData {
  const _InstitutionDashboardCardData({
    required this.key,
    required this.valueKey,
    required this.title,
    required this.value,
  });

  final Key key;
  final Key valueKey;
  final String title;
  final int value;
}
