import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../application/platform_institution_detail_controller.dart';
import '../application/platform_institution_detail_state.dart';
import '../domain/platform_institution.dart';
import '../domain/platform_institution_detail.dart';
import 'platform_dashboard_formatters.dart';

const _pageSpacing = 24.0;
const _sectionSpacing = 20.0;
const _fieldSpacing = 14.0;
const _panelRadius = 8.0;
const _wideDetailBreakpoint = 1000.0;
const _usagePanelWidth = 360.0;
const _labelWidth = 160.0;
const _notProvided = 'Not provided';

class PlatformOwnerInstitutionDetailScreen extends ConsumerWidget {
  const PlatformOwnerInstitutionDetailScreen({
    required this.institutionId,
    super.key,
  });

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionControllerProvider);
    final user = session.user;
    final key =
        session.status == AuthSessionStatus.authenticated && user != null
        ? PlatformInstitutionDetailKey(
            sessionUserId: user.id,
            sessionInstanceId: identityHashCode(user),
            institutionId: institutionId,
          )
        : null;
    final state = key == null
        ? const PlatformInstitutionDetailState.initial()
        : ref.watch(platformInstitutionDetailControllerProvider(key));

    return SingleChildScrollView(
      key: const Key('platformInstitutionDetailSurface'),
      padding: const EdgeInsets.all(_pageSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('platformInstitutionDetailBackButton'),
              onPressed: () =>
                  context.go(AppRoutePaths.platformOwnerInstitutions),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Institutions'),
            ),
          ),
          const SizedBox(height: _sectionSpacing),
          _InstitutionDetailBody(
            state: state,
            onEdit: (detail) {
              context.go(
                AppRoutePaths.platformOwnerInstitutionEditLocation(detail.id),
              );
            },
            onRetry: key == null
                ? null
                : () {
                    ref
                        .read(
                          platformInstitutionDetailControllerProvider(
                            key,
                          ).notifier,
                        )
                        .retry();
                  },
          ),
        ],
      ),
    );
  }
}

class _InstitutionDetailBody extends StatelessWidget {
  const _InstitutionDetailBody({
    required this.state,
    required this.onEdit,
    required this.onRetry,
  });

  final PlatformInstitutionDetailState state;
  final ValueChanged<PlatformInstitutionDetail> onEdit;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      PlatformInstitutionDetailStatus.initial ||
      PlatformInstitutionDetailStatus.loading =>
        const _InstitutionDetailLoading(),
      PlatformInstitutionDetailStatus.data => _InstitutionDetailData(
        detail: state.detail!,
        onEdit: onEdit,
      ),
      PlatformInstitutionDetailStatus.notFound =>
        const _InstitutionDetailNotFound(),
      PlatformInstitutionDetailStatus.error => _InstitutionDetailError(
        failure: state.failure!,
        isRetryInFlight: state.isRetryInFlight,
        onRetry: onRetry,
      ),
    };
  }
}

class _InstitutionDetailLoading extends StatelessWidget {
  const _InstitutionDetailLoading();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('platformInstitutionDetailLoading'),
      decoration: _panelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 48,
          horizontal: _pageSpacing,
        ),
        child: Center(
          child: Semantics(
            label: 'Loading institution details',
            liveRegion: true,
            child: const CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}

class _InstitutionDetailData extends StatelessWidget {
  const _InstitutionDetailData({required this.detail, required this.onEdit});

  final PlatformInstitutionDetail detail;
  final ValueChanged<PlatformInstitutionDetail> onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('platformInstitutionDetailData'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InstitutionDetailHeader(detail: detail, onEdit: onEdit),
        const SizedBox(height: _sectionSpacing),
        LayoutBuilder(
          builder: (context, constraints) {
            final basicInformation = _BasicInformationSection(detail: detail);
            final basicUsage = _BasicUsageSection(counts: detail.userCounts);

            if (constraints.maxWidth >= _wideDetailBreakpoint) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: basicInformation),
                  const SizedBox(width: _sectionSpacing),
                  SizedBox(width: _usagePanelWidth, child: basicUsage),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                basicInformation,
                const SizedBox(height: _sectionSpacing),
                basicUsage,
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InstitutionDetailHeader extends StatelessWidget {
  const _InstitutionDetailHeader({required this.detail, required this.onEdit});

  final PlatformInstitutionDetail detail;
  final ValueChanged<PlatformInstitutionDetail> onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: detail.name,
          child: Text(
            detail.name,
            key: const Key('platformInstitutionDetailTitle'),
            style: Theme.of(context).textTheme.headlineMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              key: const Key('platformInstitutionDetailTypeChip'),
              avatar: const Icon(Icons.business_outlined, size: 18),
              label: Text(platformInstitutionTypeLabel(detail.type)),
            ),
            _DetailStatusBadge(status: detail.status),
            Semantics(
              button: true,
              label: 'Edit basic information for ${detail.name}',
              child: FilledButton.icon(
                key: const Key('platformInstitutionDetailEditButton'),
                onPressed: () => onEdit(detail),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit basic information'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BasicInformationSection extends StatelessWidget {
  const _BasicInformationSection({required this.detail});

  final PlatformInstitutionDetail detail;

  @override
  Widget build(BuildContext context) {
    return _DetailPanel(
      title: 'Basic information',
      keyName: 'platformInstitutionBasicInformation',
      children: [
        _FieldRow(label: 'Name', value: detail.name),
        _FieldRow(
          label: 'Type',
          value: platformInstitutionTypeLabel(detail.type),
        ),
        _FieldRow(
          label: 'Status',
          value: platformInstitutionStatusLabel(detail.status),
        ),
        _FieldRow(
          label: 'Contact email',
          value: _optionalValue(detail.contactEmail),
        ),
        _FieldRow(
          label: 'Contact phone',
          value: _optionalValue(detail.contactPhone),
        ),
        _FieldRow(label: 'Address', value: _optionalValue(detail.address)),
        _FieldRow(
          label: 'Description',
          value: _optionalValue(detail.description),
        ),
        _FieldRow(
          label: 'Created at',
          value: formatPlatformDashboardUtcTimestamp(detail.createdAt),
        ),
        _FieldRow(
          label: 'Updated at',
          value: formatPlatformDashboardUtcTimestamp(detail.updatedAt),
        ),
      ],
    );
  }
}

class _BasicUsageSection extends StatelessWidget {
  const _BasicUsageSection({required this.counts});

  final PlatformInstitutionUserCounts counts;

  @override
  Widget build(BuildContext context) {
    return _DetailPanel(
      title: 'Basic usage',
      keyName: 'platformInstitutionBasicUsage',
      children: [
        _UsageRow(label: 'Total user accounts', value: counts.total),
        _UsageRow(label: 'Active user accounts', value: counts.active),
      ],
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.title,
    required this.keyName,
    required this.children,
  });

  final String title;
  final String keyName;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: Key(keyName),
      decoration: _panelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(_pageSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _fieldSpacing / 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidget = Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          );
          final valueWidget = Tooltip(
            message: value,
            child: Text(
              value,
              key: Key('platformInstitutionDetailValue$label'),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          );

          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 4), valueWidget],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: _labelWidth, child: labelWidget),
              const SizedBox(width: 16),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _fieldSpacing / 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              key: Key('platformInstitutionDetailUsageLabel$label'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value.toString(),
            key: Key('platformInstitutionDetailUsageValue$label'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _DetailStatusBadge extends StatelessWidget {
  const _DetailStatusBadge({required this.status});

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
        key: const Key('platformInstitutionDetailStatusChip'),
        avatar: Icon(Icons.circle, size: 10, color: color),
        label: Text(label),
      ),
    );
  }
}

class _InstitutionDetailNotFound extends StatelessWidget {
  const _InstitutionDetailNotFound();

  @override
  Widget build(BuildContext context) {
    return _CenteredDetailMessage(
      keyName: 'platformInstitutionDetailNotFound',
      icon: Icons.search_off,
      title: 'Institution not found',
      message: 'The requested institution could not be found.',
    );
  }
}

class _InstitutionDetailError extends StatelessWidget {
  const _InstitutionDetailError({
    required this.failure,
    required this.isRetryInFlight,
    required this.onRetry,
  });

  final ApiFailure failure;
  final bool isRetryInFlight;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _CenteredDetailMessage(
      keyName: 'platformInstitutionDetailError',
      icon: Icons.error_outline,
      title: 'Institution details unavailable',
      message: _institutionDetailFailureMessage(failure),
      trailing: FilledButton.icon(
        key: const Key('platformInstitutionDetailRetryButton'),
        onPressed: isRetryInFlight ? null : onRetry,
        icon: isRetryInFlight
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        label: Text(isRetryInFlight ? 'Retrying' : 'Retry'),
      ),
    );
  }
}

class _CenteredDetailMessage extends StatelessWidget {
  const _CenteredDetailMessage({
    required this.keyName,
    required this.icon,
    required this.title,
    required this.message,
    this.trailing,
  });

  final String keyName;
  final IconData icon;
  final String title;
  final String message;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: Key(keyName),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: DecoratedBox(
          decoration: _panelDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(_pageSpacing),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  key: Key('${keyName}Message'),
                  textAlign: TextAlign.center,
                ),
                if (trailing != null) ...[
                  const SizedBox(height: 20),
                  Align(alignment: Alignment.center, child: trailing!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration(BuildContext context) {
  return BoxDecoration(
    border: Border.all(color: Theme.of(context).dividerColor),
    borderRadius: BorderRadius.circular(_panelRadius),
  );
}

String _optionalValue(String? value) {
  if (value == null || value.trim().isEmpty) {
    return _notProvided;
  }

  return value;
}

String _institutionDetailFailureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.authenticationRequired => 'Please sign in again.',
    ApiErrorCodes.passwordChangeRequired =>
      'Password change is required before institution access.',
    ApiErrorCodes.userInactive => 'This account is inactive.',
    ApiErrorCodes.institutionInactive => 'This institution is inactive.',
    ApiErrorCodes.forbidden =>
      'You do not have permission to view this institution.',
    ApiErrorCodes.validationFailed =>
      'The institution detail request did not match the API contract.',
    _ => switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The institution detail request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected institution detail response.',
      ApiFailureKind.cancelled =>
        'The institution detail request was cancelled.',
      ApiFailureKind.unknown ||
      ApiFailureKind.server ||
      ApiFailureKind.validation =>
        'The institution details could not be loaded.',
    },
  };
}
