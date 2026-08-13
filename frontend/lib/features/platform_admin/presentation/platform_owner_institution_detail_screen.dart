import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_paths.dart';
import '../../../core/network/api_error_codes.dart';
import '../../../core/network/api_failure.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../application/platform_institution_admin_action_controller.dart';
import '../application/platform_institution_admin_action_state.dart';
import '../application/platform_institution_admin_create_controller.dart';
import '../application/platform_institution_admin_create_state.dart';
import '../application/platform_institution_admin_list_controller.dart';
import '../application/platform_institution_admin_list_state.dart';
import '../application/platform_institution_detail_controller.dart';
import '../application/platform_institution_detail_state.dart';
import '../application/platform_institution_lifecycle_controller.dart';
import '../application/platform_institution_lifecycle_state.dart';
import '../domain/platform_institution.dart';
import '../domain/platform_institution_admin.dart';
import '../domain/platform_institution_admin_create.dart';
import '../domain/platform_institution_admin_lifecycle.dart';
import '../domain/platform_institution_admin_list_query.dart';
import '../domain/platform_institution_admin_update.dart';
import '../domain/platform_institution_detail.dart';
import '../domain/platform_institution_lifecycle.dart';
import '../domain/platform_institution_list_query.dart';
import 'platform_dashboard_formatters.dart';

const _pageSpacing = 24.0;
const _sectionSpacing = 20.0;
const _fieldSpacing = 14.0;
const _panelRadius = 8.0;
const _wideDetailBreakpoint = 1000.0;
const _wideAdminTableBreakpoint = 1400.0;
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
  int? _adminCompletionHandledGeneration;

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
    final detail = detailState.detail;
    final adminListKey =
        detailState.status == PlatformInstitutionDetailStatus.data &&
            detail != null &&
            detail.id == widget.institutionId &&
            session.status == AuthSessionStatus.authenticated &&
            user != null
        ? PlatformInstitutionAdminListKey(
            sessionUserId: user.id,
            sessionInstanceId: identityHashCode(user),
            institutionId: widget.institutionId,
          )
        : null;
    final adminCreateKey =
        detailState.status == PlatformInstitutionDetailStatus.data &&
            detail != null &&
            detail.id == widget.institutionId &&
            session.status == AuthSessionStatus.authenticated &&
            user != null
        ? PlatformInstitutionAdminCreateKey(
            sessionUserId: user.id,
            sessionInstanceId: identityHashCode(user),
            institutionId: widget.institutionId,
          )
        : null;
    final adminActionKey =
        detailState.status == PlatformInstitutionDetailStatus.data &&
            detail != null &&
            detail.id == widget.institutionId &&
            session.status == AuthSessionStatus.authenticated &&
            user != null
        ? PlatformInstitutionAdminActionKey(
            sessionUserId: user.id,
            sessionInstanceId: identityHashCode(user),
            institutionId: widget.institutionId,
          )
        : null;
    final adminActionState = adminActionKey == null
        ? const PlatformInstitutionAdminActionState.idle()
        : ref.watch(
            platformInstitutionAdminActionControllerProvider(adminActionKey),
          );

    _handleLifecycleEffects(
      detailKey,
      lifecycleKey,
      detailState,
      lifecycleState,
    );
    _handleAdminActionEffects(adminActionKey, adminListKey, adminActionState);

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
            adminListKey: adminListKey,
            adminCreateKey: adminCreateKey,
            adminActionKey: adminActionKey,
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

  void _handleAdminActionEffects(
    PlatformInstitutionAdminActionKey? actionKey,
    PlatformInstitutionAdminListKey? listKey,
    PlatformInstitutionAdminActionState actionState,
  ) {
    if (actionKey == null || listKey == null) {
      _adminCompletionHandledGeneration = null;
      return;
    }

    final snapshot = actionState.snapshot;
    final completion = actionState.completion;
    if (snapshot == null ||
        completion == null ||
        _adminCompletionHandledGeneration == snapshot.requestGeneration) {
      return;
    }

    _adminCompletionHandledGeneration = snapshot.requestGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final provider = platformInstitutionAdminActionControllerProvider(
        actionKey,
      );
      final latestState = ref.read(provider);
      if (latestState.snapshot?.requestGeneration !=
              snapshot.requestGeneration ||
          latestState.completion != completion) {
        return;
      }

      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop(completion);
      }

      final controller = ref.read(provider.notifier);
      switch (completion.kind) {
        case PlatformInstitutionAdminActionCompletionKind.profileUpdated:
          controller.invalidateProfileSuccess();
        case PlatformInstitutionAdminActionCompletionKind.lifecycleChanged:
          controller.invalidateLifecycleSuccess();
        case PlatformInstitutionAdminActionCompletionKind.targetUnavailable:
          break;
      }

      controller.resetAfterCompletion();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            key: const Key('platformInstitutionAdminActionSnackBar'),
            content: Text(completion.message),
          ),
        );
    });
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
    required this.adminListKey,
    required this.adminCreateKey,
    required this.adminActionKey,
    required this.onEdit,
    required this.onLifecycleAction,
    required this.onRetry,
  });

  final PlatformInstitutionDetailState state;
  final PlatformInstitutionLifecycleState lifecycleState;
  final PlatformInstitutionAdminListKey? adminListKey;
  final PlatformInstitutionAdminCreateKey? adminCreateKey;
  final PlatformInstitutionAdminActionKey? adminActionKey;
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
        adminListKey: adminListKey,
        adminCreateKey: adminCreateKey,
        adminActionKey: adminActionKey,
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
    required this.adminListKey,
    required this.adminCreateKey,
    required this.adminActionKey,
    required this.onEdit,
    required this.onLifecycleAction,
  });

  final PlatformInstitutionDetail detail;
  final PlatformInstitutionLifecycleState lifecycleState;
  final PlatformInstitutionAdminListKey? adminListKey;
  final PlatformInstitutionAdminCreateKey? adminCreateKey;
  final PlatformInstitutionAdminActionKey? adminActionKey;
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
        const SizedBox(height: _sectionSpacing),
        if (adminListKey != null &&
            adminCreateKey != null &&
            adminActionKey != null)
          _InstitutionAdministratorsSection(
            key: ValueKey(
              'platformInstitutionAdministrators-${adminListKey!.institutionId}-${adminListKey!.sessionInstanceId}',
            ),
            detail: detail,
            listKey: adminListKey!,
            createKey: adminCreateKey!,
            actionKey: adminActionKey!,
          )
        else
          const _InstitutionAdministratorsWaitingSection(),
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

class _InstitutionAdministratorsWaitingSection extends StatelessWidget {
  const _InstitutionAdministratorsWaitingSection();

  @override
  Widget build(BuildContext context) {
    return _DetailPanel(
      title: 'Institution administrators',
      keyName: 'platformInstitutionAdministratorsWaiting',
      children: const [
        Text(
          'Administrator accounts load after institution details are ready.',
        ),
      ],
    );
  }
}

class _InstitutionAdministratorsSection extends ConsumerStatefulWidget {
  const _InstitutionAdministratorsSection({
    required this.detail,
    required this.listKey,
    required this.createKey,
    required this.actionKey,
    super.key,
  });

  final PlatformInstitutionDetail detail;
  final PlatformInstitutionAdminListKey listKey;
  final PlatformInstitutionAdminCreateKey createKey;
  final PlatformInstitutionAdminActionKey actionKey;

  @override
  ConsumerState<_InstitutionAdministratorsSection> createState() {
    return _InstitutionAdministratorsSectionState();
  }
}

class _InstitutionAdministratorsSectionState
    extends ConsumerState<_InstitutionAdministratorsSection> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = platformInstitutionAdminListControllerProvider(
      widget.listKey,
    );
    final state = ref.watch(provider);
    final createState = ref.watch(
      platformInstitutionAdminCreateControllerProvider(widget.createKey),
    );
    final actionState = ref.watch(
      platformInstitutionAdminActionControllerProvider(widget.actionKey),
    );
    _syncSearchText(state.searchText);
    final mutationControlsEnabled =
        actionState.canStartAction &&
        !createState.isSubmitting &&
        !createState.isOutcomeUnknown;

    return DecoratedBox(
      key: const Key('platformInstitutionAdministratorsSection'),
      decoration: _panelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(_pageSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InstitutionAdministratorsHeader(
              detail: widget.detail,
              state: state,
              canCreate: actionState.canStartAction,
              onCreate: _showCreateDialog,
            ),
            if (widget.detail.status == PlatformInstitutionStatus.inactive) ...[
              const SizedBox(height: 12),
              const _InactiveInstitutionAdminNote(),
            ],
            const SizedBox(height: 16),
            _InstitutionAdministratorsToolbar(
              state: state,
              searchController: _searchController,
              onSearchChanged: (value) =>
                  ref.read(provider.notifier).updateSearchText(value),
              onSearchSubmitted: () =>
                  ref.read(provider.notifier).commitSearchNow(),
              onStatusChanged: (status) =>
                  ref.read(provider.notifier).setStatus(status),
              onSortChanged: (sort) =>
                  ref.read(provider.notifier).toggleSort(sort),
              onDirectionToggled: () =>
                  ref.read(provider.notifier).toggleSort(state.query.sort),
              onReset: () => ref.read(provider.notifier).reset(),
            ),
            const SizedBox(height: 16),
            _InstitutionAdministratorsBody(
              state: state,
              actionControlsEnabled: mutationControlsEnabled,
              onRetry: () => ref.read(provider.notifier).retry(),
              onSort: (sort) => ref.read(provider.notifier).toggleSort(sort),
              onEdit: _showEditDialog,
              onLifecycle: _showLifecycleDialog,
            ),
            if (state.result != null) ...[
              const SizedBox(height: 16),
              _InstitutionAdministratorsPagination(
                state: state,
                onPrevious: () => ref.read(provider.notifier).previousPage(),
                onNext: () => ref.read(provider.notifier).nextPage(),
                onFirstPage: () =>
                    ref.read(provider.notifier).returnToFirstPage(),
                onPerPageChanged: (value) =>
                    ref.read(provider.notifier).setPerPage(value),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _syncSearchText(String searchText) {
    if (_searchController.text == searchText) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _searchController.text == searchText) {
        return;
      }

      _searchController.text = searchText;
    });
  }

  Future<void> _showCreateDialog() async {
    final actionState = ref.read(
      platformInstitutionAdminActionControllerProvider(widget.actionKey),
    );
    if (!actionState.canStartAction) {
      return;
    }

    final provider = platformInstitutionAdminCreateControllerProvider(
      widget.createKey,
    );
    ref.read(provider.notifier).reset();

    final result = await showDialog<PlatformInstitutionAdminCreateResult>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _CreateInstitutionAdminDialog(
        detail: widget.detail,
        listKey: widget.listKey,
        createKey: widget.createKey,
      ),
    );

    if (!mounted) {
      return;
    }

    ref.read(provider.notifier).reset();
    if (result == null) {
      return;
    }

    ref
        .read(
          platformInstitutionAdminListControllerProvider(
            widget.listKey,
          ).notifier,
        )
        .refreshAfterMutation();
    ref
        .read(
          platformInstitutionDetailControllerProvider(
            PlatformInstitutionDetailKey(
              sessionUserId: widget.createKey.sessionUserId,
              sessionInstanceId: widget.createKey.sessionInstanceId,
              institutionId: widget.createKey.institutionId,
            ),
          ).notifier,
        )
        .refreshVisibleAfterRelatedMutation();

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          key: const Key('platformInstitutionAdminCreateSuccessSnackBar'),
          content: Text(result.message),
        ),
      );
  }

  Future<void> _showEditDialog(PlatformInstitutionAdmin admin) async {
    final provider = platformInstitutionAdminActionControllerProvider(
      widget.actionKey,
    );
    final controller = ref.read(provider.notifier);
    if (!controller.beginEdit(admin)) {
      return;
    }

    final actionGeneration = ref.read(provider).snapshot?.actionGeneration;
    if (actionGeneration == null) {
      return;
    }

    await showDialog<PlatformInstitutionAdminActionCompletion>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: false,
      builder: (context) => _EditInstitutionAdminDialog(
        actionKey: widget.actionKey,
        actionGeneration: actionGeneration,
      ),
    );

    if (!mounted) {
      return;
    }

    final latestState = ref.read(provider);
    if (latestState.snapshot?.actionGeneration == actionGeneration &&
        latestState.canDismiss) {
      controller.dismiss();
    }
  }

  Future<void> _showLifecycleDialog(PlatformInstitutionAdmin admin) async {
    final provider = platformInstitutionAdminActionControllerProvider(
      widget.actionKey,
    );
    final controller = ref.read(provider.notifier);
    if (!controller.beginLifecycle(admin)) {
      return;
    }

    final actionGeneration = ref.read(provider).snapshot?.actionGeneration;
    if (actionGeneration == null) {
      return;
    }

    await showDialog<PlatformInstitutionAdminActionCompletion>(
      context: context,
      barrierDismissible: true,
      useRootNavigator: false,
      builder: (context) => _InstitutionAdminLifecycleDialog(
        actionKey: widget.actionKey,
        actionGeneration: actionGeneration,
      ),
    );

    if (!mounted) {
      return;
    }

    final latestState = ref.read(provider);
    if (latestState.snapshot?.actionGeneration == actionGeneration &&
        latestState.canDismiss) {
      controller.dismiss();
    }
  }
}

class _InstitutionAdministratorsHeader extends StatelessWidget {
  const _InstitutionAdministratorsHeader({
    required this.detail,
    required this.state,
    required this.canCreate,
    required this.onCreate,
  });

  final PlatformInstitutionDetail detail;
  final PlatformInstitutionAdminListState state;
  final bool canCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final count = state.result?.pagination.total;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Institution administrators',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (count != null)
              Text(
                '$count matching administrators',
                key: const Key('platformInstitutionAdminCount'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        FilledButton.icon(
          key: const Key('platformInstitutionAdminCreateButton'),
          onPressed: canCreate ? onCreate : null,
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Add administrator'),
        ),
      ],
    );
  }
}

class _InactiveInstitutionAdminNote extends StatelessWidget {
  const _InactiveInstitutionAdminNote();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('platformInstitutionAdminInactiveInstitutionNote'),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.error),
        borderRadius: BorderRadius.circular(_panelRadius),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'This institution is inactive. Normal institution access is blocked until reactivation, but Platform Owner can still manage administrator accounts.',
        ),
      ),
    );
  }
}

class _InstitutionAdministratorsToolbar extends StatelessWidget {
  const _InstitutionAdministratorsToolbar({
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onDirectionToggled,
    required this.onReset,
  });

  final PlatformInstitutionAdminListState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<PlatformInstitutionAdminStatus?> onStatusChanged;
  final ValueChanged<PlatformInstitutionAdminListSort> onSortChanged;
  final VoidCallback onDirectionToggled;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final controlsEnabled = !state.isRetryInFlight;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            key: const Key('platformInstitutionAdminSearchField'),
            controller: searchController,
            enabled: controlsEnabled,
            maxLength: platformInstitutionAdminMaxSearchLength,
            textInputAction: TextInputAction.search,
            onChanged: onSearchChanged,
            onSubmitted: (_) => onSearchSubmitted(),
            decoration: InputDecoration(
              labelText: 'Search administrators',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                key: const Key('platformInstitutionAdminSearchCommitButton'),
                tooltip: 'Search now',
                onPressed: controlsEnabled ? onSearchSubmitted : null,
                icon: const Icon(Icons.keyboard_return),
              ),
              errorText: state.searchErrorText,
              counterText: '',
            ),
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<PlatformInstitutionAdminStatus?>(
            key: const Key('platformInstitutionAdminStatusFilter'),
            initialValue: state.query.status,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: null, child: Text('All statuses')),
              DropdownMenuItem(
                value: PlatformInstitutionAdminStatus.active,
                child: Text('Active'),
              ),
              DropdownMenuItem(
                value: PlatformInstitutionAdminStatus.inactive,
                child: Text('Inactive'),
              ),
            ],
            onChanged: controlsEnabled ? onStatusChanged : null,
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<PlatformInstitutionAdminListSort>(
            key: const Key('platformInstitutionAdminSortField'),
            initialValue: state.query.sort,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Sort by'),
            items: const [
              DropdownMenuItem(
                value: PlatformInstitutionAdminListSort.fullName,
                child: Text('Full name'),
              ),
              DropdownMenuItem(
                value: PlatformInstitutionAdminListSort.loginName,
                child: Text('Login name'),
              ),
              DropdownMenuItem(
                value: PlatformInstitutionAdminListSort.createdAt,
                child: Text('Created at'),
              ),
              DropdownMenuItem(
                value: PlatformInstitutionAdminListSort.updatedAt,
                child: Text('Updated at'),
              ),
            ],
            onChanged: controlsEnabled
                ? (sort) {
                    if (sort != null) {
                      onSortChanged(sort);
                    }
                  }
                : null,
          ),
        ),
        Tooltip(
          message: state.query.direction == PlatformSortDirection.asc
              ? 'Sort descending'
              : 'Sort ascending',
          child: IconButton.outlined(
            key: const Key('platformInstitutionAdminDirectionButton'),
            onPressed: controlsEnabled ? onDirectionToggled : null,
            icon: Icon(
              state.query.direction == PlatformSortDirection.asc
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
            ),
          ),
        ),
        TextButton.icon(
          key: const Key('platformInstitutionAdminResetFiltersButton'),
          onPressed: controlsEnabled ? onReset : null,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Reset'),
        ),
      ],
    );
  }
}

class _InstitutionAdministratorsBody extends StatelessWidget {
  const _InstitutionAdministratorsBody({
    required this.state,
    required this.actionControlsEnabled,
    required this.onRetry,
    required this.onSort,
    required this.onEdit,
    required this.onLifecycle,
  });

  final PlatformInstitutionAdminListState state;
  final bool actionControlsEnabled;
  final VoidCallback onRetry;
  final ValueChanged<PlatformInstitutionAdminListSort> onSort;
  final ValueChanged<PlatformInstitutionAdmin> onEdit;
  final ValueChanged<PlatformInstitutionAdmin> onLifecycle;

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      PlatformInstitutionAdminListStatus.waitingForInstitutionDetail =>
        const _InstitutionAdministratorsMessage(
          keyName: 'platformInstitutionAdminWaiting',
          icon: Icons.hourglass_empty,
          title: 'Waiting for institution details',
          message: 'Administrator accounts load after details are ready.',
        ),
      PlatformInstitutionAdminListStatus.initial ||
      PlatformInstitutionAdminListStatus.loading =>
        const _InstitutionAdministratorsLoading(
          keyName: 'platformInstitutionAdminInitialLoading',
          label: 'Loading administrators',
        ),
      PlatformInstitutionAdminListStatus.queryLoading =>
        const _InstitutionAdministratorsLoading(
          keyName: 'platformInstitutionAdminQueryLoading',
          label: 'Loading administrators',
        ),
      PlatformInstitutionAdminListStatus.error =>
        _InstitutionAdministratorsError(
          failure: state.failure!,
          isRetryInFlight: state.isRetryInFlight,
          onRetry: onRetry,
        ),
      PlatformInstitutionAdminListStatus.globalEmpty =>
        const _InstitutionAdministratorsMessage(
          keyName: 'platformInstitutionAdminGlobalEmpty',
          icon: Icons.person_off_outlined,
          title: 'No administrators yet',
          message:
              'Create the first Institution Admin account for this institution.',
        ),
      PlatformInstitutionAdminListStatus.filteredEmpty =>
        const _InstitutionAdministratorsMessage(
          keyName: 'platformInstitutionAdminFilteredEmpty',
          icon: Icons.manage_search_outlined,
          title: 'No matching administrators',
          message: 'Adjust the search or status filter.',
        ),
      PlatformInstitutionAdminListStatus.emptyPage =>
        const _InstitutionAdministratorsMessage(
          keyName: 'platformInstitutionAdminEmptyPage',
          icon: Icons.last_page_outlined,
          title: 'This page is empty',
          message: 'Return to an earlier page or adjust the filters.',
        ),
      PlatformInstitutionAdminListStatus.data => _InstitutionAdministratorsRows(
        admins: state.result!.admins,
        query: state.query,
        actionControlsEnabled: actionControlsEnabled,
        onSort: onSort,
        onEdit: onEdit,
        onLifecycle: onLifecycle,
      ),
    };
  }
}

class _InstitutionAdministratorsRows extends StatelessWidget {
  const _InstitutionAdministratorsRows({
    required this.admins,
    required this.query,
    required this.actionControlsEnabled,
    required this.onSort,
    required this.onEdit,
    required this.onLifecycle,
  });

  final List<PlatformInstitutionAdmin> admins;
  final PlatformInstitutionAdminListQuery query;
  final bool actionControlsEnabled;
  final ValueChanged<PlatformInstitutionAdminListSort> onSort;
  final ValueChanged<PlatformInstitutionAdmin> onEdit;
  final ValueChanged<PlatformInstitutionAdmin> onLifecycle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideAdminTableBreakpoint) {
          return _InstitutionAdministratorsTable(
            admins: admins,
            query: query,
            actionControlsEnabled: actionControlsEnabled,
            onSort: onSort,
            onEdit: onEdit,
            onLifecycle: onLifecycle,
          );
        }

        return Column(
          key: const Key('platformInstitutionAdminCardList'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final admin in admins) ...[
              _InstitutionAdminCard(
                admin: admin,
                actionControlsEnabled: actionControlsEnabled,
                onEdit: onEdit,
                onLifecycle: onLifecycle,
              ),
              if (admin != admins.last) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _InstitutionAdministratorsTable extends StatelessWidget {
  const _InstitutionAdministratorsTable({
    required this.admins,
    required this.query,
    required this.actionControlsEnabled,
    required this.onSort,
    required this.onEdit,
    required this.onLifecycle,
  });

  final List<PlatformInstitutionAdmin> admins;
  final PlatformInstitutionAdminListQuery query;
  final bool actionControlsEnabled;
  final ValueChanged<PlatformInstitutionAdminListSort> onSort;
  final ValueChanged<PlatformInstitutionAdmin> onEdit;
  final ValueChanged<PlatformInstitutionAdmin> onLifecycle;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      key: const Key('platformInstitutionAdminTable'),
      sortColumnIndex: _sortColumnIndex(query.sort),
      sortAscending: query.direction == PlatformSortDirection.asc,
      columnSpacing: 20,
      dataRowMinHeight: 64,
      dataRowMaxHeight: 92,
      columns: [
        DataColumn(
          label: const Text('Full name'),
          onSort: (_, _) => onSort(PlatformInstitutionAdminListSort.fullName),
        ),
        DataColumn(
          label: const Text('Login name'),
          onSort: (_, _) => onSort(PlatformInstitutionAdminListSort.loginName),
        ),
        const DataColumn(label: Text('Contact')),
        const DataColumn(label: Text('Account')),
        DataColumn(
          label: const Text('Created'),
          onSort: (_, _) => onSort(PlatformInstitutionAdminListSort.createdAt),
        ),
        const DataColumn(label: Text('Last login')),
        const DataColumn(label: Text('Actions')),
      ],
      rows: [
        for (final admin in admins)
          DataRow(
            key: ValueKey('platformInstitutionAdminRow-${admin.id}'),
            cells: [
              DataCell(_AdminTableText(admin.fullName, maxWidth: 220)),
              DataCell(_AdminTableText(admin.loginName, maxWidth: 180)),
              DataCell(
                _AdminStackedValues(
                  first: _optionalValue(admin.email),
                  second: _optionalValue(admin.phone),
                  maxWidth: 240,
                ),
              ),
              DataCell(_AdminAccountSummary(admin: admin)),
              DataCell(
                _AdminTableText(
                  formatPlatformDashboardUtcTimestamp(admin.createdAt),
                  maxWidth: 160,
                ),
              ),
              DataCell(
                _AdminTableText(
                  _optionalTimestamp(admin.lastLoginAt),
                  maxWidth: 160,
                ),
              ),
              DataCell(
                _AdminActionButtons(
                  admin: admin,
                  enabled: actionControlsEnabled,
                  compact: true,
                  onEdit: onEdit,
                  onLifecycle: onLifecycle,
                ),
              ),
            ],
          ),
      ],
    );
  }

  int? _sortColumnIndex(PlatformInstitutionAdminListSort sort) {
    return switch (sort) {
      PlatformInstitutionAdminListSort.fullName => 0,
      PlatformInstitutionAdminListSort.loginName => 1,
      PlatformInstitutionAdminListSort.createdAt => 4,
      PlatformInstitutionAdminListSort.updatedAt => null,
    };
  }
}

class _InstitutionAdminCard extends StatelessWidget {
  const _InstitutionAdminCard({
    required this.admin,
    required this.actionControlsEnabled,
    required this.onEdit,
    required this.onLifecycle,
  });

  final PlatformInstitutionAdmin admin;
  final bool actionControlsEnabled;
  final ValueChanged<PlatformInstitutionAdmin> onEdit;
  final ValueChanged<PlatformInstitutionAdmin> onLifecycle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey('platformInstitutionAdminCard-${admin.id}'),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(_panelRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              admin.fullName,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AdminStatusChip(isActive: admin.isActive),
                Chip(label: Text(_passwordChangeLabel(admin))),
              ],
            ),
            const SizedBox(height: 10),
            _AdminFact(label: 'Login name', value: admin.loginName),
            _AdminFact(label: 'Email', value: _optionalValue(admin.email)),
            _AdminFact(label: 'Phone', value: _optionalValue(admin.phone)),
            _AdminFact(
              label: 'Last login',
              value: _optionalTimestamp(admin.lastLoginAt),
            ),
            _AdminFact(
              label: 'Created at',
              value: formatPlatformDashboardUtcTimestamp(admin.createdAt),
            ),
            const SizedBox(height: 12),
            _AdminActionButtons(
              admin: admin,
              enabled: actionControlsEnabled,
              compact: false,
              onEdit: onEdit,
              onLifecycle: onLifecycle,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminActionButtons extends StatelessWidget {
  const _AdminActionButtons({
    required this.admin,
    required this.enabled,
    required this.compact,
    required this.onEdit,
    required this.onLifecycle,
  });

  final PlatformInstitutionAdmin admin;
  final bool enabled;
  final bool compact;
  final ValueChanged<PlatformInstitutionAdmin> onEdit;
  final ValueChanged<PlatformInstitutionAdmin> onLifecycle;

  @override
  Widget build(BuildContext context) {
    final lifecycleAction = PlatformInstitutionAdminLifecycleAction.forAdmin(
      admin,
    );
    final lifecycleIcon =
        lifecycleAction == PlatformInstitutionAdminLifecycleAction.deactivate
        ? Icons.pause_circle_outline
        : Icons.check_circle_outline;
    final lifecycleKey =
        lifecycleAction == PlatformInstitutionAdminLifecycleAction.deactivate
        ? 'platformInstitutionAdminDeactivateButton-${admin.id}'
        : 'platformInstitutionAdminActivateButton-${admin.id}';

    final children = [
      Semantics(
        button: true,
        label: 'Edit administrator ${admin.loginName}',
        child: OutlinedButton.icon(
          key: Key('platformInstitutionAdminEditButton-${admin.id}'),
          onPressed: enabled ? () => onEdit(admin) : null,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
      ),
      Semantics(
        button: true,
        label:
            '${lifecycleAction.confirmLabel} administrator ${admin.loginName}',
        child: FilledButton.icon(
          key: Key(lifecycleKey),
          onPressed: enabled ? () => onLifecycle(admin) : null,
          icon: Icon(lifecycleIcon),
          label: Text(lifecycleAction.confirmLabel),
        ),
      ),
    ];

    if (compact) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Wrap(spacing: 8, runSpacing: 8, children: children),
      );
    }

    return Semantics(
      label: 'Administrator actions for ${admin.loginName}',
      child: Wrap(spacing: 8, runSpacing: 8, children: children),
    );
  }
}

class _AdminTableText extends StatelessWidget {
  const _AdminTableText(this.value, {required this.maxWidth});

  final String value;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Tooltip(
        message: value,
        child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _AdminStackedValues extends StatelessWidget {
  const _AdminStackedValues({
    required this.first,
    required this.second,
    required this.maxWidth,
  });

  final String first;
  final String second;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: first,
            child: Text(first, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 4),
          Tooltip(
            message: second,
            child: Text(
              second,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminAccountSummary extends StatelessWidget {
  const _AdminAccountSummary({required this.admin});

  final PlatformInstitutionAdmin admin;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 170),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _AdminStatusChip(isActive: admin.isActive),
          Chip(label: Text(_passwordChangeLabel(admin))),
        ],
      ),
    );
  }
}

class _AdminStatusChip extends StatelessWidget {
  const _AdminStatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final label = isActive ? 'Active' : 'Inactive';
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    return Semantics(
      label: 'Administrator account status: $label',
      child: Chip(
        avatar: Icon(Icons.circle, size: 10, color: color),
        label: Text(label),
      ),
    );
  }
}

class _AdminFact extends StatelessWidget {
  const _AdminFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidget = Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          );
          final valueWidget = Tooltip(
            message: value,
            child: Text(value, maxLines: 3, overflow: TextOverflow.ellipsis),
          );

          if (constraints.maxWidth < 380) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 2), valueWidget],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 110, child: labelWidget),
              const SizedBox(width: 12),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _InstitutionAdministratorsPagination extends StatelessWidget {
  const _InstitutionAdministratorsPagination({
    required this.state,
    required this.onPrevious,
    required this.onNext,
    required this.onFirstPage,
    required this.onPerPageChanged,
  });

  final PlatformInstitutionAdminListState state;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFirstPage;
  final ValueChanged<int> onPerPageChanged;

  @override
  Widget build(BuildContext context) {
    final pagination = state.result!.pagination;

    return Wrap(
      key: const Key('platformInstitutionAdminPagination'),
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.end,
      children: [
        Text(
          'Page ${pagination.page} of ${pagination.lastPage} · Total ${pagination.total}',
          key: const Key('platformInstitutionAdminPaginationSummary'),
        ),
        DropdownButton<int>(
          key: const Key('platformInstitutionAdminPageSizeField'),
          value: state.query.perPage,
          items: [
            for (final option in platformInstitutionAdminPageSizeOptions)
              DropdownMenuItem(value: option, child: Text('$option per page')),
          ],
          onChanged: state.isRequestInFlight
              ? null
              : (value) {
                  if (value != null) {
                    onPerPageChanged(value);
                  }
                },
        ),
        IconButton.outlined(
          key: const Key('platformInstitutionAdminFirstPageButton'),
          tooltip: 'First page',
          onPressed: state.canGoPrevious ? onFirstPage : null,
          icon: const Icon(Icons.first_page),
        ),
        IconButton.outlined(
          key: const Key('platformInstitutionAdminPreviousPageButton'),
          tooltip: 'Previous page',
          onPressed: state.canGoPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton.outlined(
          key: const Key('platformInstitutionAdminNextPageButton'),
          tooltip: 'Next page',
          onPressed: state.canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _InstitutionAdministratorsLoading extends StatelessWidget {
  const _InstitutionAdministratorsLoading({
    required this.keyName,
    required this.label,
  });

  final String keyName;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: Key(keyName),
      height: 128,
      child: Center(
        child: Semantics(
          label: label,
          liveRegion: true,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _InstitutionAdministratorsError extends StatelessWidget {
  const _InstitutionAdministratorsError({
    required this.failure,
    required this.isRetryInFlight,
    required this.onRetry,
  });

  final ApiFailure failure;
  final bool isRetryInFlight;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _InstitutionAdministratorsMessage(
      keyName: 'platformInstitutionAdminError',
      icon: Icons.error_outline,
      title: 'Administrators unavailable',
      message: _institutionAdminListFailureMessage(failure),
      trailing: FilledButton.icon(
        key: const Key('platformInstitutionAdminRetryButton'),
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

class _InstitutionAdministratorsMessage extends StatelessWidget {
  const _InstitutionAdministratorsMessage({
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
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                key: Key('${keyName}Message'),
              ),
              if (trailing != null) ...[const SizedBox(height: 16), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditInstitutionAdminDialog extends ConsumerStatefulWidget {
  const _EditInstitutionAdminDialog({
    required this.actionKey,
    required this.actionGeneration,
  });

  final PlatformInstitutionAdminActionKey actionKey;
  final int actionGeneration;

  @override
  ConsumerState<_EditInstitutionAdminDialog> createState() {
    return _EditInstitutionAdminDialogState();
  }
}

class _EditInstitutionAdminDialogState
    extends ConsumerState<_EditInstitutionAdminDialog> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final FocusNode _fullNameFocusNode;
  late final FocusNode _emailFocusNode;
  late final FocusNode _phoneFocusNode;
  PlatformInstitutionAdminEditField? _focusedErrorField;
  var _completionHandled = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _fullNameFocusNode = FocusNode();
    _emailFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _fullNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = platformInstitutionAdminActionControllerProvider(
      widget.actionKey,
    );
    final state = ref.watch(provider);
    if (!_isInstitutionAdminActionRouteCurrent(context, widget.actionKey)) {
      _closeStaleDialog();
      return const AlertDialog(
        key: Key('platformInstitutionAdminEditUnavailableDialog'),
        title: Text('Edit administrator'),
        content: Text('The administrator action is no longer available.'),
      );
    }

    _handleEffects(state);
    if (_completionHandled) {
      return const SizedBox.shrink();
    }

    final snapshot = state.snapshot;
    final form = state.form;

    if (state.status == PlatformInstitutionAdminActionStatus.idle ||
        snapshot == null ||
        snapshot.actionGeneration != widget.actionGeneration ||
        snapshot.kind != PlatformInstitutionAdminActionKind.edit ||
        form == null) {
      if (!_completionHandled) {
        _closeStaleDialog();
      }
      return const AlertDialog(
        key: Key('platformInstitutionAdminEditUnavailableDialog'),
        title: Text('Edit administrator'),
        content: Text('The administrator action is no longer available.'),
      );
    }

    _syncEditControllers(form);

    return PopScope(
      canPop: !state.isBusy,
      child: AlertDialog(
        key: const Key('platformInstitutionAdminEditDialog'),
        title: const Text('Edit administrator'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _EditInstitutionAdminDialogContent(
              state: state,
              snapshot: snapshot,
              fullNameController: _fullNameController,
              emailController: _emailController,
              phoneController: _phoneController,
              fullNameFocusNode: _fullNameFocusNode,
              emailFocusNode: _emailFocusNode,
              phoneFocusNode: _phoneFocusNode,
              onFullNameChanged: (value) =>
                  ref.read(provider.notifier).updateFullName(value),
              onEmailChanged: (value) =>
                  ref.read(provider.notifier).updateEmail(value),
              onPhoneChanged: (value) =>
                  ref.read(provider.notifier).updatePhone(value),
              onSubmit: () => ref.read(provider.notifier).submitEdit(),
            ),
          ),
        ),
        actions: _buildEditActions(context, ref, state),
      ),
    );
  }

  List<Widget> _buildEditActions(
    BuildContext context,
    WidgetRef ref,
    PlatformInstitutionAdminActionState state,
  ) {
    final provider = platformInstitutionAdminActionControllerProvider(
      widget.actionKey,
    );

    if (state.status == PlatformInstitutionAdminActionStatus.unknownOutcome) {
      return [
        FilledButton(
          key: const Key('platformInstitutionAdminEditCloseButton'),
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Close'),
        ),
      ];
    }

    return [
      TextButton(
        key: const Key('platformInstitutionAdminEditCancelButton'),
        onPressed: state.isBusy ? null : () => Navigator.of(context).pop(null),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        key: const Key('platformInstitutionAdminEditSubmitButton'),
        onPressed: state.canSubmitEdit
            ? () => ref.read(provider.notifier).submitEdit()
            : null,
        icon: state.isBusy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(state.isBusy ? 'Saving administrator' : 'Save changes'),
      ),
    ];
  }

  void _handleEffects(PlatformInstitutionAdminActionState state) {
    final completion = state.completion;
    if (completion != null && !_completionHandled) {
      _completionHandled = true;
      return;
    }

    final firstErrorField = state.firstErrorField;
    if (firstErrorField != null && firstErrorField != _focusedErrorField) {
      _focusedErrorField = firstErrorField;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _focusNodeFor(firstErrorField).requestFocus();
      });
    }
  }

  void _syncEditControllers(PlatformInstitutionAdminEditFormValue form) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _setControllerText(_fullNameController, form.fullName);
      _setControllerText(_emailController, form.email);
      _setControllerText(_phoneController, form.phone);
    });
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }

    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  FocusNode _focusNodeFor(PlatformInstitutionAdminEditField field) {
    return switch (field) {
      PlatformInstitutionAdminEditField.fullName => _fullNameFocusNode,
      PlatformInstitutionAdminEditField.email => _emailFocusNode,
      PlatformInstitutionAdminEditField.phone => _phoneFocusNode,
    };
  }

  void _closeStaleDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(null);
      }
    });
  }
}

class _EditInstitutionAdminDialogContent extends StatelessWidget {
  const _EditInstitutionAdminDialogContent({
    required this.state,
    required this.snapshot,
    required this.fullNameController,
    required this.emailController,
    required this.phoneController,
    required this.fullNameFocusNode,
    required this.emailFocusNode,
    required this.phoneFocusNode,
    required this.onFullNameChanged,
    required this.onEmailChanged,
    required this.onPhoneChanged,
    required this.onSubmit,
  });

  final PlatformInstitutionAdminActionState state;
  final PlatformInstitutionAdminActionSnapshot snapshot;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final FocusNode fullNameFocusNode;
  final FocusNode emailFocusNode;
  final FocusNode phoneFocusNode;
  final ValueChanged<String> onFullNameChanged;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPhoneChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final canEdit =
        !state.isBusy &&
        state.status != PlatformInstitutionAdminActionStatus.unknownOutcome;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdminDialogContext(admin: snapshot.admin),
        if (state.formError != null) ...[
          const SizedBox(height: 12),
          _AdminActionMessage(
            keyName: 'platformInstitutionAdminEditFormError',
            message: state.formError!,
          ),
        ],
        if (state.message != null &&
            (state.status == PlatformInstitutionAdminActionStatus.reconciling ||
                state.status ==
                    PlatformInstitutionAdminActionStatus.definiteFailure ||
                state.status ==
                    PlatformInstitutionAdminActionStatus.unknownOutcome)) ...[
          const SizedBox(height: 12),
          _AdminActionMessage(
            keyName: 'platformInstitutionAdminEditStateMessage',
            message: state.message!,
            showProgress:
                state.status ==
                PlatformInstitutionAdminActionStatus.reconciling,
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          key: const Key('platformInstitutionAdminEditFullNameField'),
          controller: fullNameController,
          focusNode: fullNameFocusNode,
          autofocus: true,
          enabled: canEdit,
          textInputAction: TextInputAction.next,
          onChanged: onFullNameChanged,
          onSubmitted: (_) => emailFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Full name *',
            errorText: state.errorTextFor(
              PlatformInstitutionAdminEditField.fullName,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('platformInstitutionAdminEditEmailField'),
          controller: emailController,
          focusNode: emailFocusNode,
          enabled: canEdit,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onChanged: onEmailChanged,
          onSubmitted: (_) => phoneFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Email',
            errorText: state.errorTextFor(
              PlatformInstitutionAdminEditField.email,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('platformInstitutionAdminEditPhoneField'),
          controller: phoneController,
          focusNode: phoneFocusNode,
          enabled: canEdit,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onChanged: onPhoneChanged,
          onSubmitted: (_) {
            if (state.canSubmitEdit) {
              onSubmit();
            }
          },
          decoration: InputDecoration(
            labelText: 'Phone',
            errorText: state.errorTextFor(
              PlatformInstitutionAdminEditField.phone,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstitutionAdminLifecycleDialog extends ConsumerStatefulWidget {
  const _InstitutionAdminLifecycleDialog({
    required this.actionKey,
    required this.actionGeneration,
  });

  final PlatformInstitutionAdminActionKey actionKey;
  final int actionGeneration;

  @override
  ConsumerState<_InstitutionAdminLifecycleDialog> createState() {
    return _InstitutionAdminLifecycleDialogState();
  }
}

class _InstitutionAdminLifecycleDialogState
    extends ConsumerState<_InstitutionAdminLifecycleDialog> {
  var _completionHandled = false;

  @override
  Widget build(BuildContext context) {
    final provider = platformInstitutionAdminActionControllerProvider(
      widget.actionKey,
    );
    final state = ref.watch(provider);
    if (!_isInstitutionAdminActionRouteCurrent(context, widget.actionKey)) {
      _closeStaleDialog();
      return const AlertDialog(
        key: Key('platformInstitutionAdminLifecycleUnavailableDialog'),
        title: Text('Administrator lifecycle'),
        content: Text('The administrator action is no longer available.'),
      );
    }

    _handleEffects(state);
    if (_completionHandled) {
      return const SizedBox.shrink();
    }

    final snapshot = state.snapshot;
    final action = snapshot?.lifecycleAction;

    if (state.status == PlatformInstitutionAdminActionStatus.idle ||
        snapshot == null ||
        snapshot.actionGeneration != widget.actionGeneration ||
        snapshot.kind != PlatformInstitutionAdminActionKind.lifecycle ||
        action == null) {
      if (!_completionHandled) {
        _closeStaleDialog();
      }
      return const AlertDialog(
        key: Key('platformInstitutionAdminLifecycleUnavailableDialog'),
        title: Text('Administrator lifecycle'),
        content: Text('The administrator action is no longer available.'),
      );
    }

    return PopScope(
      canPop: !state.isBusy,
      child: AlertDialog(
        key: const Key('platformInstitutionAdminLifecycleDialog'),
        title: Text(action.title),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _InstitutionAdminLifecycleDialogContent(
              state: state,
              snapshot: snapshot,
              action: action,
            ),
          ),
        ),
        actions: _buildLifecycleActions(context, ref, state, action),
      ),
    );
  }

  List<Widget> _buildLifecycleActions(
    BuildContext context,
    WidgetRef ref,
    PlatformInstitutionAdminActionState state,
    PlatformInstitutionAdminLifecycleAction action,
  ) {
    final provider = platformInstitutionAdminActionControllerProvider(
      widget.actionKey,
    );

    if (state.status ==
        PlatformInstitutionAdminActionStatus.lifecycleConfirming) {
      return [
        TextButton(
          key: const Key('platformInstitutionAdminLifecycleCancelButton'),
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: Key(
            action == PlatformInstitutionAdminLifecycleAction.deactivate
                ? 'platformInstitutionAdminLifecycleConfirmDeactivateButton'
                : 'platformInstitutionAdminLifecycleConfirmActivateButton',
          ),
          onPressed: () => ref.read(provider.notifier).confirmLifecycle(),
          icon: Icon(
            action == PlatformInstitutionAdminLifecycleAction.deactivate
                ? Icons.pause_circle_outline
                : Icons.check_circle_outline,
          ),
          label: Text(action.confirmLabel),
        ),
      ];
    }

    if (state.isBusy) {
      return [
        const TextButton(
          key: Key('platformInstitutionAdminLifecycleCancelButton'),
          onPressed: null,
          child: Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('platformInstitutionAdminLifecycleSubmittingButton'),
          onPressed: null,
          icon: const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: Text(
            state.status == PlatformInstitutionAdminActionStatus.reconciling
                ? 'Checking administrator'
                : '${action.confirmLabel} in progress',
          ),
        ),
      ];
    }

    return [
      FilledButton(
        key: const Key('platformInstitutionAdminLifecycleCloseButton'),
        onPressed: () => Navigator.of(context).pop(null),
        child: const Text('Close'),
      ),
    ];
  }

  void _handleEffects(PlatformInstitutionAdminActionState state) {
    final completion = state.completion;
    if (completion != null && !_completionHandled) {
      _completionHandled = true;
    }
  }

  void _closeStaleDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(null);
      }
    });
  }
}

bool _isInstitutionAdminActionRouteCurrent(
  BuildContext context,
  PlatformInstitutionAdminActionKey actionKey,
) {
  final currentPath = GoRouter.of(
    context,
  ).routeInformationProvider.value.uri.path;
  return currentPath ==
      AppRoutePaths.platformOwnerInstitutionDetailLocation(
        actionKey.institutionId,
      );
}

class _InstitutionAdminLifecycleDialogContent extends StatelessWidget {
  const _InstitutionAdminLifecycleDialogContent({
    required this.state,
    required this.snapshot,
    required this.action,
  });

  final PlatformInstitutionAdminActionState state;
  final PlatformInstitutionAdminActionSnapshot snapshot;
  final PlatformInstitutionAdminLifecycleAction action;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdminDialogContext(admin: snapshot.admin),
        const SizedBox(height: 16),
        _AdminLifecycleStatusLine(
          label: 'Target account status',
          value: action == PlatformInstitutionAdminLifecycleAction.activate
              ? 'Active'
              : 'Inactive',
        ),
        const SizedBox(height: 16),
        if (state.message != null &&
            state.status !=
                PlatformInstitutionAdminActionStatus.lifecycleConfirming)
          _AdminActionMessage(
            keyName: 'platformInstitutionAdminLifecycleStateMessage',
            message: state.message!,
            showProgress:
                state.status ==
                PlatformInstitutionAdminActionStatus.reconciling,
          )
        else
          Text(
            _adminLifecycleConsequence(action),
            key: const Key('platformInstitutionAdminLifecycleConsequence'),
          ),
      ],
    );
  }
}

class _AdminDialogContext extends StatelessWidget {
  const _AdminDialogContext({required this.admin});

  final PlatformInstitutionAdmin admin;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('platformInstitutionAdminDialogContext'),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(_panelRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              admin.fullName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _AdminLifecycleStatusLine(
              label: 'Login name',
              value: admin.loginName,
            ),
            _AdminLifecycleStatusLine(
              label: 'Current account status',
              value: admin.isActive ? 'Active' : 'Inactive',
            ),
            _AdminLifecycleStatusLine(
              label: 'Password change',
              value: _passwordChangeLabel(admin),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminLifecycleStatusLine extends StatelessWidget {
  const _AdminLifecycleStatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _AdminActionMessage extends StatelessWidget {
  const _AdminActionMessage({
    required this.keyName,
    required this.message,
    this.showProgress = false,
  });

  final String keyName;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        key: Key(keyName),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.primary),
          borderRadius: BorderRadius.circular(_panelRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showProgress) ...[
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateInstitutionAdminDialog extends ConsumerStatefulWidget {
  const _CreateInstitutionAdminDialog({
    required this.detail,
    required this.listKey,
    required this.createKey,
  });

  final PlatformInstitutionDetail detail;
  final PlatformInstitutionAdminListKey listKey;
  final PlatformInstitutionAdminCreateKey createKey;

  @override
  ConsumerState<_CreateInstitutionAdminDialog> createState() {
    return _CreateInstitutionAdminDialogState();
  }
}

class _CreateInstitutionAdminDialogState
    extends ConsumerState<_CreateInstitutionAdminDialog> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _loginNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final FocusNode _fullNameFocusNode;
  late final FocusNode _loginNameFocusNode;
  late final FocusNode _emailFocusNode;
  late final FocusNode _phoneFocusNode;
  late final FocusNode _passwordFocusNode;
  var _obscurePassword = true;
  int? _handledPasswordWipeGeneration;
  var _successHandled = false;
  PlatformInstitutionAdminCreateField? _focusedErrorField;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _loginNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _fullNameFocusNode = FocusNode();
    _loginNameFocusNode = FocusNode();
    _emailFocusNode = FocusNode();
    _phoneFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _loginNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _fullNameFocusNode.dispose();
    _loginNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = platformInstitutionAdminCreateControllerProvider(
      widget.createKey,
    );
    final state = ref.watch(provider);
    _handleDialogEffects(state);
    _syncFormControllers(state.form);

    return PopScope(
      canPop: !state.isSubmitting,
      child: AlertDialog(
        key: const Key('platformInstitutionAdminCreateDialog'),
        title: Text('Add administrator for ${widget.detail.name}'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _CreateInstitutionAdminDialogContent(
              detail: widget.detail,
              state: state,
              fullNameController: _fullNameController,
              loginNameController: _loginNameController,
              emailController: _emailController,
              phoneController: _phoneController,
              passwordController: _passwordController,
              fullNameFocusNode: _fullNameFocusNode,
              loginNameFocusNode: _loginNameFocusNode,
              emailFocusNode: _emailFocusNode,
              phoneFocusNode: _phoneFocusNode,
              passwordFocusNode: _passwordFocusNode,
              obscurePassword: _obscurePassword,
              onTogglePasswordVisibility: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              onFullNameChanged: (value) =>
                  ref.read(provider.notifier).updateFullName(value),
              onLoginNameChanged: (value) =>
                  ref.read(provider.notifier).updateLoginName(value),
              onEmailChanged: (value) =>
                  ref.read(provider.notifier).updateEmail(value),
              onPhoneChanged: (value) =>
                  ref.read(provider.notifier).updatePhone(value),
              onPasswordChanged: (_) =>
                  ref.read(provider.notifier).clearPasswordError(),
              onSubmit: _submit,
            ),
          ),
        ),
        actions: _buildDialogActions(context, state),
      ),
    );
  }

  List<Widget> _buildDialogActions(
    BuildContext context,
    PlatformInstitutionAdminCreateState state,
  ) {
    if (state.isOutcomeUnknown) {
      return [
        TextButton(
          key: const Key('platformInstitutionAdminCreateCloseButton'),
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          key: const Key('platformInstitutionAdminCreateRefreshButton'),
          onPressed: () => ref
              .read(
                platformInstitutionAdminListControllerProvider(
                  widget.listKey,
                ).notifier,
              )
              .refreshAfterMutation(),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh administrators'),
        ),
      ];
    }

    return [
      TextButton(
        key: const Key('platformInstitutionAdminCreateCancelButton'),
        onPressed: state.isSubmitting
            ? null
            : () => Navigator.of(context).pop(null),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        key: const Key('platformInstitutionAdminCreateSubmitButton'),
        onPressed: state.canSubmit ? _submit : null,
        icon: state.isSubmitting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add_alt_1_outlined),
        label: Text(
          state.isSubmitting
              ? 'Creating administrator'
              : 'Create administrator',
        ),
      ),
    ];
  }

  void _submit() {
    final provider = platformInstitutionAdminCreateControllerProvider(
      widget.createKey,
    );
    ref.read(provider.notifier).submit(password: _passwordController.text);
  }

  void _handleDialogEffects(PlatformInstitutionAdminCreateState state) {
    if (_handledPasswordWipeGeneration != state.passwordWipeGeneration) {
      _handledPasswordWipeGeneration = state.passwordWipeGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _passwordController.clear();
        }
      });
    }

    final firstErrorField = state.firstErrorField;
    if (firstErrorField != null && firstErrorField != _focusedErrorField) {
      _focusedErrorField = firstErrorField;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _focusNodeFor(firstErrorField).requestFocus();
      });
    }

    final result = state.result;
    if (state.status == PlatformInstitutionAdminCreateStatus.success &&
        result != null &&
        !_successHandled) {
      _successHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _passwordController.clear();
        Navigator.of(context).pop(result);
      });
    }
  }

  void _syncFormControllers(PlatformInstitutionAdminCreateFormValue form) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _setControllerText(_fullNameController, form.fullName);
      _setControllerText(_loginNameController, form.loginName);
      _setControllerText(_emailController, form.email);
      _setControllerText(_phoneController, form.phone);
    });
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }

    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  FocusNode _focusNodeFor(PlatformInstitutionAdminCreateField field) {
    return switch (field) {
      PlatformInstitutionAdminCreateField.fullName => _fullNameFocusNode,
      PlatformInstitutionAdminCreateField.loginName => _loginNameFocusNode,
      PlatformInstitutionAdminCreateField.email => _emailFocusNode,
      PlatformInstitutionAdminCreateField.phone => _phoneFocusNode,
      PlatformInstitutionAdminCreateField.password => _passwordFocusNode,
    };
  }
}

class _CreateInstitutionAdminDialogContent extends StatelessWidget {
  const _CreateInstitutionAdminDialogContent({
    required this.detail,
    required this.state,
    required this.fullNameController,
    required this.loginNameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.fullNameFocusNode,
    required this.loginNameFocusNode,
    required this.emailFocusNode,
    required this.phoneFocusNode,
    required this.passwordFocusNode,
    required this.obscurePassword,
    required this.onTogglePasswordVisibility,
    required this.onFullNameChanged,
    required this.onLoginNameChanged,
    required this.onEmailChanged,
    required this.onPhoneChanged,
    required this.onPasswordChanged,
    required this.onSubmit,
  });

  final PlatformInstitutionDetail detail;
  final PlatformInstitutionAdminCreateState state;
  final TextEditingController fullNameController;
  final TextEditingController loginNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final FocusNode fullNameFocusNode;
  final FocusNode loginNameFocusNode;
  final FocusNode emailFocusNode;
  final FocusNode phoneFocusNode;
  final FocusNode passwordFocusNode;
  final bool obscurePassword;
  final VoidCallback onTogglePasswordVisibility;
  final ValueChanged<String> onFullNameChanged;
  final ValueChanged<String> onLoginNameChanged;
  final ValueChanged<String> onEmailChanged;
  final ValueChanged<String> onPhoneChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final canEdit =
        !state.isSubmitting &&
        state.status != PlatformInstitutionAdminCreateStatus.success &&
        state.status != PlatformInstitutionAdminCreateStatus.outcomeUnknown;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'The new account is created active and must change the initial password on first login.',
          key: const Key('platformInstitutionAdminCreateConsequence'),
        ),
        if (detail.status == PlatformInstitutionStatus.inactive) ...[
          const SizedBox(height: 10),
          const _InactiveInstitutionAdminNote(),
        ],
        if (state.formError != null) ...[
          const SizedBox(height: 12),
          _CreateInstitutionAdminFormError(message: state.formError!),
        ],
        const SizedBox(height: 16),
        TextField(
          key: const Key('platformInstitutionAdminCreateFullNameField'),
          controller: fullNameController,
          focusNode: fullNameFocusNode,
          autofocus: true,
          enabled: canEdit,
          textInputAction: TextInputAction.next,
          onChanged: onFullNameChanged,
          onSubmitted: (_) => loginNameFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Full name *',
            errorText: state.errorTextFor(
              PlatformInstitutionAdminCreateField.fullName,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('platformInstitutionAdminCreateLoginNameField'),
          controller: loginNameController,
          focusNode: loginNameFocusNode,
          enabled: canEdit,
          textInputAction: TextInputAction.next,
          onChanged: onLoginNameChanged,
          onSubmitted: (_) => emailFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Login name *',
            errorText: state.errorTextFor(
              PlatformInstitutionAdminCreateField.loginName,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('platformInstitutionAdminCreateEmailField'),
          controller: emailController,
          focusNode: emailFocusNode,
          enabled: canEdit,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onChanged: onEmailChanged,
          onSubmitted: (_) => phoneFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Email',
            errorText: state.errorTextFor(
              PlatformInstitutionAdminCreateField.email,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('platformInstitutionAdminCreatePhoneField'),
          controller: phoneController,
          focusNode: phoneFocusNode,
          enabled: canEdit,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          onChanged: onPhoneChanged,
          onSubmitted: (_) => passwordFocusNode.requestFocus(),
          decoration: InputDecoration(
            labelText: 'Phone',
            errorText: state.errorTextFor(
              PlatformInstitutionAdminCreateField.phone,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('platformInstitutionAdminCreatePasswordField'),
          controller: passwordController,
          focusNode: passwordFocusNode,
          enabled: canEdit,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          onChanged: onPasswordChanged,
          onSubmitted: (_) {
            if (state.canSubmit) {
              onSubmit();
            }
          },
          decoration: InputDecoration(
            labelText: 'Initial password *',
            errorText: state.errorTextFor(
              PlatformInstitutionAdminCreateField.password,
            ),
            suffixIcon: IconButton(
              key: const Key(
                'platformInstitutionAdminCreatePasswordVisibilityButton',
              ),
              tooltip: obscurePassword ? 'Show password' : 'Hide password',
              onPressed: canEdit ? onTogglePasswordVisibility : null,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateInstitutionAdminFormError extends StatelessWidget {
  const _CreateInstitutionAdminFormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        key: const Key('platformInstitutionAdminCreateFormError'),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.error),
          borderRadius: BorderRadius.circular(_panelRadius),
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
      ),
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

String _adminLifecycleConsequence(
  PlatformInstitutionAdminLifecycleAction action,
) {
  return switch (action) {
    PlatformInstitutionAdminLifecycleAction.activate =>
      'Activation restores only the account active state. An inactive Institution still blocks normal access, password change may still be required, and this action does not create a session, reset a password, or change role.',
    PlatformInstitutionAdminLifecycleAction.deactivate =>
      'Normal protected access for this administrator is blocked immediately. Institution binding, credentials, first-login state, and historical data remain unchanged, and this action does not deactivate the Institution or other users.',
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

String _optionalTimestamp(DateTime? value) {
  if (value == null) {
    return 'Never';
  }

  return formatPlatformDashboardUtcTimestamp(value);
}

String _passwordChangeLabel(PlatformInstitutionAdmin admin) {
  return admin.mustChangePassword
      ? 'Password change required'
      : 'Password change completed';
}

String _institutionAdminListFailureMessage(ApiFailure failure) {
  return switch (failure.serverCode) {
    ApiErrorCodes.authenticationRequired => 'Please sign in again.',
    ApiErrorCodes.passwordChangeRequired =>
      'Password change is required before administrator access.',
    ApiErrorCodes.userInactive => 'This account is inactive.',
    ApiErrorCodes.institutionInactive => 'This institution is inactive.',
    ApiErrorCodes.forbidden =>
      'You do not have permission to view institution administrators.',
    ApiErrorCodes.resourceNotFound => 'The institution could not be found.',
    ApiErrorCodes.validationFailed =>
      'The administrator list request did not match the API contract.',
    _ => switch (failure.kind) {
      ApiFailureKind.connection =>
        'Could not reach the server. Check the connection and try again.',
      ApiFailureKind.timeout => 'The administrator list request timed out.',
      ApiFailureKind.invalidResponse =>
        'The server returned an unexpected administrator list response.',
      ApiFailureKind.cancelled =>
        'The administrator list request was cancelled.',
      ApiFailureKind.unknown ||
      ApiFailureKind.server ||
      ApiFailureKind.validation => 'Administrators could not be loaded.',
    },
  };
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
