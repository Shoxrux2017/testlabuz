import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/domain/user_role.dart';

const _compactRailWidth = 136.0;
const _expandedRailWidth = 256.0;
const _expandedRailBreakpoint = 1100.0;
const _stackedHeaderBreakpoint = 680.0;
const _shellSpacing = 24.0;
const _headerVerticalPadding = 16.0;
const _headerItemSpacing = 12.0;

class InstitutionAdminShell extends ConsumerWidget {
  const InstitutionAdminShell({
    required this.locationPath,
    required this.child,
    super.key,
  });

  final String locationPath;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionControllerProvider);
    final surface = ref.watch(appDeviceSurfaceProvider);
    final user = session.user;

    if (session.status != AuthSessionStatus.authenticated || user == null) {
      return const _NeutralInstitutionAdminShell();
    }

    final destination = InstitutionAdminShellDestination.fromPath(locationPath);
    final pageTitle = _pageTitleForPath(locationPath);
    if (!_hasValidSessionContext(
      user: user,
      surface: surface,
      locationPath: locationPath,
      destination: destination,
      pageTitle: pageTitle,
    )) {
      return const _InstitutionAdminShellUnavailable();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isExpanded = constraints.maxWidth >= _expandedRailBreakpoint;

        return Scaffold(
          key: const Key('institutionAdminShell'),
          body: SafeArea(
            child: FocusTraversalGroup(
              policy: WidgetOrderTraversalPolicy(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InstitutionAdminNavigation(
                    locationPath: locationPath,
                    selectedDestination: destination!,
                    isExpanded: isExpanded,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _InstitutionAdminHeader(
                          pageTitle: pageTitle!,
                          user: user,
                        ),
                        const Divider(height: 1),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum InstitutionAdminShellDestination {
  dashboard(
    label: 'Dashboard',
    path: AppRoutePaths.institutionAdmin,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  users(
    label: 'Users',
    path: AppRoutePaths.institutionAdminUsers,
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
  ),
  institution(
    label: 'Institution',
    path: AppRoutePaths.institutionAdminInstitution,
    icon: Icons.business_outlined,
    selectedIcon: Icons.business,
  ),
  settings(
    label: 'Settings',
    path: AppRoutePaths.institutionAdminSettings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  );

  const InstitutionAdminShellDestination({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;

  static InstitutionAdminShellDestination? fromPath(String path) {
    for (final destination in values) {
      if (destination.path == path) {
        return destination;
      }
    }

    if (AppRoutePaths.isInstitutionAdminUserCreatePath(path) ||
        AppRoutePaths.isInstitutionAdminUserDetailPath(path)) {
      return InstitutionAdminShellDestination.users;
    }

    return null;
  }
}

bool _hasValidSessionContext({
  required AuthUser user,
  required AppDeviceSurface surface,
  required String locationPath,
  required InstitutionAdminShellDestination? destination,
  required String? pageTitle,
}) {
  final institutionId = user.institutionId;
  final institution = user.institution;

  return user.role == UserRole.institutionAdmin &&
      surface == AppDeviceSurface.desktop &&
      user.isActive &&
      !user.mustChangePassword &&
      institutionId != null &&
      institutionId.trim().isNotEmpty &&
      institution != null &&
      institution.id == institutionId &&
      institution.status == 'active' &&
      AppRoutePaths.isInstitutionAdminApprovedLocation(locationPath) &&
      destination != null &&
      pageTitle != null;
}

String? _pageTitleForPath(String path) {
  if (path == AppRoutePaths.institutionAdmin) {
    return 'Dashboard';
  }
  if (path == AppRoutePaths.institutionAdminUsers) {
    return 'Users';
  }
  if (AppRoutePaths.isInstitutionAdminUserCreatePath(path)) {
    return 'Create User';
  }
  if (AppRoutePaths.isInstitutionAdminUserDetailPath(path)) {
    return 'User Details';
  }
  if (path == AppRoutePaths.institutionAdminInstitution) {
    return 'Institution';
  }
  if (path == AppRoutePaths.institutionAdminSettings) {
    return 'Settings';
  }

  return null;
}

class _InstitutionAdminNavigation extends StatelessWidget {
  const _InstitutionAdminNavigation({
    required this.locationPath,
    required this.selectedDestination,
    required this.isExpanded,
  });

  final String locationPath;
  final InstitutionAdminShellDestination selectedDestination;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final destinations = InstitutionAdminShellDestination.values;
    final router = GoRouter.of(context);

    return SizedBox(
      width: isExpanded ? _expandedRailWidth : _compactRailWidth,
      child: NavigationRail(
        key: const Key('institutionAdminNavigation'),
        extended: isExpanded,
        minExtendedWidth: _expandedRailWidth,
        labelType: isExpanded ? null : NavigationRailLabelType.all,
        selectedIndex: destinations.indexOf(selectedDestination),
        onDestinationSelected: (index) {
          final destination = destinations[index];
          if (destination.path == locationPath) {
            return;
          }

          router.push(destination.path);
        },
        destinations: [
          for (final destination in destinations)
            NavigationRailDestination(
              icon: _DestinationIcon(destination: destination, selected: false),
              selectedIcon: _DestinationIcon(
                destination: destination,
                selected: true,
              ),
              label: Text(destination.label),
            ),
        ],
      ),
    );
  }
}

class _DestinationIcon extends StatelessWidget {
  const _DestinationIcon({required this.destination, required this.selected});

  final InstitutionAdminShellDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: destination.label,
      child: Icon(selected ? destination.selectedIcon : destination.icon),
    );
  }
}

class _InstitutionAdminHeader extends ConsumerWidget {
  const _InstitutionAdminHeader({required this.pageTitle, required this.user});

  final String pageTitle;
  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institution = user.institution!;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final usesStackedLayout =
            constraints.maxWidth < _stackedHeaderBreakpoint || textScale > 1.5;
        final identity = _InstitutionAdminHeaderIdentity(pageTitle: pageTitle);
        final sessionContext = _InstitutionAdminHeaderSessionContext(
          fullName: user.fullName,
          institutionName: institution.name,
        );
        final signOut = _SignOutButton(
          onPressed: () {
            ref.read(authSessionControllerProvider.notifier).signOut();
          },
        );

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _shellSpacing,
            vertical: _headerVerticalPadding,
          ),
          child: usesStackedLayout
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    const SizedBox(height: _headerItemSpacing),
                    sessionContext,
                    const SizedBox(height: _headerItemSpacing),
                    Align(alignment: Alignment.centerRight, child: signOut),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: _shellSpacing),
                    Flexible(child: sessionContext),
                    const SizedBox(width: _headerItemSpacing),
                    signOut,
                  ],
                ),
        );
      },
    );
  }
}

class _InstitutionAdminHeaderIdentity extends StatelessWidget {
  const _InstitutionAdminHeaderIdentity({required this.pageTitle});

  final String pageTitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'TestLabUz',
          key: const Key('institutionAdminProductName'),
          style: textTheme.titleMedium,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(
            pageTitle,
            key: const Key('institutionAdminPageTitle'),
            style: textTheme.headlineSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Institution Admin',
          key: const Key('institutionAdminRoleLabel'),
          style: textTheme.labelLarge,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _InstitutionAdminHeaderSessionContext extends StatelessWidget {
  const _InstitutionAdminHeaderSessionContext({
    required this.fullName,
    required this.institutionName,
  });

  final String fullName;
  final String institutionName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Current user: $fullName',
          key: const Key('institutionAdminCurrentUser'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          'Institution: $institutionName',
          key: const Key('institutionAdminInstitutionName'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const Key('entryLogoutButton'),
      onPressed: onPressed,
      icon: const Icon(Icons.logout),
      label: const Text('Sign out'),
    );
  }
}

class _NeutralInstitutionAdminShell extends StatelessWidget {
  const _NeutralInstitutionAdminShell();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}

class _InstitutionAdminShellUnavailable extends ConsumerWidget {
  const _InstitutionAdminShellUnavailable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(_shellSpacing),
            child: ConstrainedBox(
              key: const Key('institutionAdminUnavailable'),
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Session route unavailable',
                    style: textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _SignOutButton(
                    onPressed: () {
                      ref
                          .read(authSessionControllerProvider.notifier)
                          .signOut();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
