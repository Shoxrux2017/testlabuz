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
import '../application/platform_institution_lifecycle_controller.dart';
import '../application/platform_institution_lifecycle_state.dart';
import '../domain/platform_institution.dart';
import '../domain/platform_institution_detail.dart';
import '../domain/platform_institution_lifecycle.dart';
import 'platform_dashboard_formatters.dart';

const _pageSpacing = 24.0;
const _sectionSpacing = 20.0;
const _fieldSpacing = 14.0;
const _panelRadius = 8.0;
const _wideDetailBreakpoint = 1000.0;
const _usagePanelWidth = 360.0;
const _labelWidth = 160.0;
const _notProvided = 'Not provided';

class PlatformOwnerInstitutionDetailScreen extends ConsumerStatefulWidget {
  const PlatformOwnerInstitutionDetailScreen({
    required this.institutionId,
    super.key,
  });

  final String institutionId;

  @override
  ConsumerState<PlatformOwnerInstitutionDetailScreen> createState() {
    return _PlatformOwnerInstitutionDetailScreenState();
  }
}

class _PlatformOwnerInstitutionDetailScreenState
    extends ConsumerState<PlatformOwnerInstitutionDetailScreen> {
  int? _dialogRequestedGeneration;
  int? _activeDialogGeneration;
  int? _closedDialogGeneration;
  int? _snackShownGeneration;
  int? _refreshRequestedGeneration;
  int? _acknowledgedRefreshGeneration;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionControllerProvider);
    final user = session.user;
    final detailKey =
        session.status == AuthSessionStatus.authenticated && user != null
        ? PlatformInstitutionDetailKey(
            sessionUserId: user.id,
            sessionInstanceId: identityHashCode(user),
            institutionId: widget.institutionId,
          )
        : null;
    final lifecycleKey =
        session.status == AuthSessionStatus.authenticated && user != null
        ? PlatformInstitutionLifecycleKey(
            sessionUserId: user.id,
            sessionInstanceId: identityHashCode(user),
            institutionId: widget.institutionId,
          )
        : null;
    final detailState = detailKey == null
        ? const PlatformInstitutionDetailState.initial()
        : ref.watch(platformInstitutionDetailControllerProvider(detailKey));
    final lifecycleState = lifecycleKey == null
        ? const PlatformInstitutionLifecycleState.idle()
        : ref.watch(
            platformInstitutionLifecycleControllerProvider(lifecycleKey),
          );

    _handleLifecycleEffects(
      detailKey,
      lifecycleKey,
      detailState,
      lifecycleState,
    );

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
            state: detailState,
            lifecycleState: lifecycleState,
            onEdit: (detail) {
              context.go(
                AppRoutePaths.platformOwnerInstitutionEditLocation(detail.id),
              );
            },
            onLifecycleAction: lifecycleKey == null
                ? null
                : (detail) {
                    ref
                        .read(
                          platformInstitutionLifecycleControllerProvider(
                            lifecycleKey,
                          ).notifier,
                        )
                        .beginConfirmation(detail);
                  },
            onRetry: detailKey == null
                ? null
                : () {
                    ref
                        .read(
                          platformInstitutionDetailControllerProvider(
                            detailKey,
                          ).notifier,
                        )
                        .retry();
                  },
          ),
        ],
      ),
    );
  }

  void _handleLifecycleEffects(
    PlatformInstitutionDetailKey? detailKey,
    PlatformInstitutionLifecycleKey? lifecycleKey,
    PlatformInstitutionDetailState detailState,
    PlatformInstitutionLifecycleState lifecycleState,
  ) {
    if (lifecycleKey == null) {
      _dialogRequestedGeneration = null;
      _activeDialogGeneration = null;
      _refreshRequestedGeneration = null;
      return;
    }

    final operation = lifecycleState.operation;
    if (operation == null) {
      return;
    }

    if (lifecycleState.status ==
            PlatformInstitutionLifecycleStatus.confirming &&
        _dialogRequestedGeneration != operation.requestGeneration) {
      _dialogRequestedGeneration = operation.requestGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _showLifecycleDialog(lifecycleKey, operation);
      });
    }

    final result = lifecycleState.result;
    if (lifecycleState.status == PlatformInstitutionLifecycleStatus.confirmed &&
        result != null &&
        _closedDialogGeneration != operation.requestGeneration) {
      _closedDialogGeneration = operation.requestGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        if (_activeDialogGeneration == operation.requestGeneration) {
          final navigator = Navigator.of(context, rootNavigator: true);
          if (navigator.canPop()) {
            navigator.pop(true);
          }
        }

        if (_snackShownGeneration != operation.requestGeneration) {
          _snackShownGeneration = operation.requestGeneration;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                key: const Key('platformInstitutionLifecycleSuccessSnackBar'),
                content: Text(result.message),
              ),
            );
        }
      });
    }

    if (detailKey != null &&
        lifecycleState.status == PlatformInstitutionLifecycleStatus.confirmed &&
        lifecycleState.result != null &&
        _refreshRequestedGeneration != operation.requestGeneration) {
      _refreshRequestedGeneration = operation.requestGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        ref
            .read(
              platformInstitutionDetailControllerProvider(detailKey).notifier,
            )
            .refreshAfterMutation();
      });
    }

    final detail = detailState.detail;
    if (lifecycleState.status == PlatformInstitutionLifecycleStatus.confirmed &&
        result != null &&
        detailState.status == PlatformInstitutionDetailStatus.data &&
        detail != null &&
        detail.id == operation.institutionId &&
        detail.status == result.status &&
        _acknowledgedRefreshGeneration != operation.requestGeneration) {
      _acknowledgedRefreshGeneration = operation.requestGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        ref
            .read(
              platformInstitutionLifecycleControllerProvider(
                lifecycleKey,
              ).notifier,
            )
            .acknowledgeRefreshedDetail(detail);
      });
    }
  }

  Future<void> _showLifecycleDialog(
    PlatformInstitutionLifecycleKey lifecycleKey,
    PlatformInstitutionLifecycleOperation operation,
  ) async {
    _activeDialogGeneration = operation.requestGeneration;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _LifecycleConfirmationDialog(
        lifecycleKey: lifecycleKey,
        requestGeneration: operation.requestGeneration,
      ),
    );

    if (!mounted) {
      return;
    }

    if (_activeDialogGeneration == operation.requestGeneration) {
      _activeDialogGeneration = null;
    }

    if (result == true) {
      return;
    }

    final provider = platformInstitutionLifecycleControllerProvider(
      lifecycleKey,
    );
    final latestState = ref.read(provider);
    if (latestState.operation?.requestGeneration ==
            operation.requestGeneration &&
        latestState.canDismiss) {
      ref.read(provider.notifier).dismiss();
    }
  }
}

class _InstitutionDetailBody extends StatelessWidget {
  const _InstitutionDetailBody({
    required this.state,
    required this.lifecycleState,
    required this.onEdit,
    required this.onLifecycleAction,
    required this.onRetry,
  });

  final PlatformInstitutionDetailState state;
  final PlatformInstitutionLifecycleState lifecycleState;
  final ValueChanged<PlatformInstitutionDetail> onEdit;
  final ValueChanged<PlatformInstitutionDetail>? onLifecycleAction;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      PlatformInstitutionDetailStatus.initial ||
      PlatformInstitutionDetailStatus.loading =>
        const _InstitutionDetailLoading(),
      PlatformInstitutionDetailStatus.data => _InstitutionDetailData(
        detail: state.detail!,
        lifecycleState: lifecycleState,
        onEdit: onEdit,
        onLifecycleAction: onLifecycleAction,
      ),
      PlatformInstitutionDetailStatus.notFound =>
        const _InstitutionDetailNotFound(),
      PlatformInstitutionDetailStatus.error =>
        lifecycleState.hasConfirmedTargetEvidence
            ? _InstitutionDetailConfirmedRefreshError(
                result: lifecycleState.result!,
                isRetryInFlight: state.isRetryInFlight,
                onRetry: onRetry,
              )
            : _InstitutionDetailError(
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
  const _InstitutionDetailData({
    required this.detail,
    required this.lifecycleState,
    required this.onEdit,
    required this.onLifecycleAction,
  });

  final PlatformInstitutionDetail detail;
  final PlatformInstitutionLifecycleState lifecycleState;
  final ValueChanged<PlatformInstitutionDetail> onEdit;
  final ValueChanged<PlatformInstitutionDetail>? onLifecycleAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('platformInstitutionDetailData'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InstitutionDetailHeader(
          detail: detail,
          lifecycleState: lifecycleState,
          onEdit: onEdit,
          onLifecycleAction: onLifecycleAction,
        ),
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
  const _InstitutionDetailHeader({
    required this.detail,
    required this.lifecycleState,
    required this.onEdit,
    required this.onLifecycleAction,
  });

  final PlatformInstitutionDetail detail;
  final PlatformInstitutionLifecycleState lifecycleState;
  final ValueChanged<PlatformInstitutionDetail> onEdit;
  final ValueChanged<PlatformInstitutionDetail>? onLifecycleAction;

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
            _LifecycleActionButton(
              detail: detail,
              enabled:
                  lifecycleState.canOpenConfirmation &&
                  onLifecycleAction != null,
              onPressed: onLifecycleAction == null
                  ? null
                  : () => onLifecycleAction!(detail),
            ),
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

class _LifecycleActionButton extends StatelessWidget {
  const _LifecycleActionButton({
    required this.detail,
    required this.enabled,
    required this.onPressed,
  });

  final PlatformInstitutionDetail detail;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final action = PlatformInstitutionLifecycleAction.forSourceStatus(
      detail.status,
    );
    final label = action.confirmLabel;
    final isDeactivation =
        action == PlatformInstitutionLifecycleAction.deactivate;
    final buttonKey = isDeactivation
        ? const Key('platformInstitutionLifecycleDeactivateButton')
        : const Key('platformInstitutionLifecycleActivateButton');
    final icon = isDeactivation
        ? Icons.pause_circle_outline
        : Icons.check_circle_outline;
    final style = isDeactivation
        ? FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          )
        : null;

    return Semantics(
      button: true,
      label: '$label institution ${detail.name}',
      child: FilledButton.icon(
        key: buttonKey,
        onPressed: enabled ? onPressed : null,
        style: style,
        icon: Icon(icon),
        label: Text(label),
      ),
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

class _LifecycleConfirmationDialog extends ConsumerWidget {
  const _LifecycleConfirmationDialog({
    required this.lifecycleKey,
    required this.requestGeneration,
  });

  final PlatformInstitutionLifecycleKey lifecycleKey;
  final int requestGeneration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = platformInstitutionLifecycleControllerProvider(
      lifecycleKey,
    );
    final state = ref.watch(provider);
    final operation = state.operation;

    if (operation == null || operation.requestGeneration != requestGeneration) {
      return AlertDialog(
        key: const Key('platformInstitutionLifecycleUnavailableDialog'),
        title: const Text('Institution lifecycle'),
        content: const Text('The lifecycle action is no longer available.'),
        actions: [
          FilledButton(
            key: const Key(
              'platformInstitutionLifecycleUnavailableCloseButton',
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return PopScope(
      canPop: !state.isBusy,
      child: AlertDialog(
        key: const Key('platformInstitutionLifecycleDialog'),
        title: Text(operation.action.title),
        content: SingleChildScrollView(
          child: _LifecycleDialogContent(operation: operation, state: state),
        ),
        actions: _buildLifecycleDialogActions(context, ref, state, operation),
      ),
    );
  }

  List<Widget> _buildLifecycleDialogActions(
    BuildContext context,
    WidgetRef ref,
    PlatformInstitutionLifecycleState state,
    PlatformInstitutionLifecycleOperation operation,
  ) {
    final provider = platformInstitutionLifecycleControllerProvider(
      lifecycleKey,
    );
    final isDeactivation =
        operation.action == PlatformInstitutionLifecycleAction.deactivate;
    final destructiveStyle = isDeactivation
        ? FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          )
        : null;

    if (state.status == PlatformInstitutionLifecycleStatus.confirming) {
      return [
        TextButton(
          key: const Key('platformInstitutionLifecycleCancelButton'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: Key(
            isDeactivation
                ? 'platformInstitutionLifecycleConfirmDeactivateButton'
                : 'platformInstitutionLifecycleConfirmActivateButton',
          ),
          onPressed: () {
            ref.read(provider.notifier).confirm();
          },
          style: destructiveStyle,
          icon: Icon(isDeactivation ? Icons.pause_circle_outline : Icons.check),
          label: Text(operation.action.confirmLabel),
        ),
      ];
    }

    if (state.status == PlatformInstitutionLifecycleStatus.submitting) {
      return [
        const TextButton(
          key: Key('platformInstitutionLifecycleCancelButton'),
          onPressed: null,
          child: Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('platformInstitutionLifecycleSubmittingButton'),
          onPressed: null,
          style: destructiveStyle,
          icon: const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: Text('${operation.action.confirmLabel} in progress'),
        ),
      ];
    }

    if (state.status == PlatformInstitutionLifecycleStatus.reconciling) {
      return [
        const TextButton(
          key: Key('platformInstitutionLifecycleCloseButton'),
          onPressed: null,
          child: Text('Close'),
        ),
        FilledButton.icon(
          key: const Key('platformInstitutionLifecycleCheckingButton'),
          onPressed: null,
          icon: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: Text('Checking status'),
        ),
      ];
    }

    if (state.status == PlatformInstitutionLifecycleStatus.unknownOutcome &&
        state.canCheckStatus) {
      return [
        TextButton(
          key: const Key('platformInstitutionLifecycleCloseButton'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          key: const Key('platformInstitutionLifecycleCheckStatusButton'),
          onPressed: () {
            ref.read(provider.notifier).checkStatus();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Check status'),
        ),
      ];
    }

    return [
      FilledButton(
        key: const Key('platformInstitutionLifecycleCloseButton'),
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Close'),
      ),
    ];
  }
}

class _LifecycleDialogContent extends StatelessWidget {
  const _LifecycleDialogContent({required this.operation, required this.state});

  final PlatformInstitutionLifecycleOperation operation;
  final PlatformInstitutionLifecycleState state;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            operation.institutionName,
            key: const Key('platformInstitutionLifecycleInstitutionName'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _LifecycleStatusLine(
            label: 'Current status',
            status: operation.sourceStatus,
          ),
          const SizedBox(height: 8),
          _LifecycleStatusLine(
            label: 'Target status',
            status: operation.targetStatus,
          ),
          const SizedBox(height: 16),
          if (state.status == PlatformInstitutionLifecycleStatus.submitting)
            _LifecycleProgressMessage(
              label: '${operation.action.confirmLabel} request in progress',
            )
          else if (state.status ==
              PlatformInstitutionLifecycleStatus.reconciling)
            const _LifecycleProgressMessage(label: 'Checking current status')
          else if (state.status ==
                  PlatformInstitutionLifecycleStatus.definiteFailure ||
              state.status == PlatformInstitutionLifecycleStatus.unknownOutcome)
            _LifecycleStateMessage(state: state)
          else
            Text(
              _lifecycleConsequence(operation.action),
              key: const Key('platformInstitutionLifecycleConsequence'),
            ),
        ],
      ),
    );
  }
}

class _LifecycleStatusLine extends StatelessWidget {
  const _LifecycleStatusLine({required this.label, required this.status});

  final String label;
  final PlatformInstitutionStatus status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(width: 12),
        Chip(label: Text(platformInstitutionStatusLabel(status))),
      ],
    );
  }
}

class _LifecycleProgressMessage extends StatelessWidget {
  const _LifecycleProgressMessage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _LifecycleStateMessage extends StatelessWidget {
  const _LifecycleStateMessage({required this.state});

  final PlatformInstitutionLifecycleState state;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        key: Key(
          state.status == PlatformInstitutionLifecycleStatus.unknownOutcome
              ? 'platformInstitutionLifecycleUnknownMessage'
              : 'platformInstitutionLifecycleFailureMessage',
        ),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.primary),
          borderRadius: BorderRadius.circular(_panelRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(state.message ?? 'Lifecycle action did not complete.'),
        ),
      ),
    );
  }
}

String _lifecycleConsequence(PlatformInstitutionLifecycleAction action) {
  return switch (action) {
    PlatformInstitutionLifecycleAction.activate =>
      'Eligible users may use this Institution again according to each account\'s active state, first-login requirement, role, relationships, and permissions.',
    PlatformInstitutionLifecycleAction.deactivate =>
      'Institution Admins, Teachers, Students, and Parents will lose normal Institution access. Historical data is preserved.',
  };
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

class _InstitutionDetailConfirmedRefreshError extends StatelessWidget {
  const _InstitutionDetailConfirmedRefreshError({
    required this.result,
    required this.isRetryInFlight,
    required this.onRetry,
  });

  final PlatformInstitutionLifecycleResult result;
  final bool isRetryInFlight;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final statusLabel = platformInstitutionStatusLabel(result.status);

    return _CenteredDetailMessage(
      keyName: 'platformInstitutionLifecycleConfirmedRefreshError',
      icon: Icons.sync_problem_outlined,
      title: 'Institution status update confirmed',
      message:
          'Server confirmed status: $statusLabel. '
          'Details could not be refreshed.',
      trailing: FilledButton.icon(
        key: const Key('platformInstitutionLifecycleRefreshDetailsButton'),
        onPressed: isRetryInFlight ? null : onRetry,
        icon: isRetryInFlight
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        label: Text(isRetryInFlight ? 'Refreshing details' : 'Refresh details'),
      ),
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
