import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/device/app_device_surface.dart';
import '../../../app/router/app_route_paths.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/domain/user_role.dart';

const _compactRailWidth = 96.0;
const _expandedRailWidth = 232.0;
const _expandedRailBreakpoint = 1100.0;
const _shellSpacing = 24.0;
const _headerVerticalPadding = 16.0;

class PlatformOwnerShell extends ConsumerWidget {
  const PlatformOwnerShell({
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
      return const _NeutralPlatformOwnerShell();
    }

    final destination = PlatformOwnerShellDestination.fromPath(locationPath);
    if (user.role != UserRole.platformOwner ||
        surface != AppDeviceSurface.desktop ||
        destination == null) {
      return const _PlatformOwnerShellUnavailable();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isExpanded = constraints.maxWidth >= _expandedRailBreakpoint;

        return Scaffold(
          key: const Key('platformOwnerShell'),
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PlatformOwnerNavigation(
                  locationPath: locationPath,
                  selectedDestination: destination,
                  isExpanded: isExpanded,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PlatformOwnerHeader(
                        destination: destination,
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
        );
      },
    );
  }
}

enum PlatformOwnerShellDestination {
  dashboard(
    label: 'Dashboard',
    path: AppRoutePaths.platformOwner,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  institutions(
    label: 'Institutions',
    path: AppRoutePaths.platformOwnerInstitutions,
    icon: Icons.business_outlined,
    selectedIcon: Icons.business,
  );

  const PlatformOwnerShellDestination({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;

  static PlatformOwnerShellDestination? fromPath(String path) {
    for (final destination in values) {
      if (destination.path == path) {
        return destination;
      }
    }

    if (AppRoutePaths.isPlatformOwnerInstitutionDetailPath(path)) {
      return PlatformOwnerShellDestination.institutions;
    }

    if (AppRoutePaths.isPlatformOwnerInstitutionEditPath(path)) {
      return PlatformOwnerShellDestination.institutions;
    }

    if (AppRoutePaths.isPlatformOwnerInstitutionCreatePath(path)) {
      return PlatformOwnerShellDestination.institutions;
    }

    return null;
  }
}

class _PlatformOwnerNavigation extends StatelessWidget {
  const _PlatformOwnerNavigation({
    required this.locationPath,
    required this.selectedDestination,
    required this.isExpanded,
  });

  final String locationPath;
  final PlatformOwnerShellDestination selectedDestination;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final destinations = PlatformOwnerShellDestination.values;
    final router = GoRouter.of(context);

    return SizedBox(
      width: isExpanded ? _expandedRailWidth : _compactRailWidth,
      child: NavigationRail(
        key: const Key('platformOwnerNavigation'),
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
              label: Text(
                destination.label,
                key: Key('platformOwnerNav${destination.label}Label'),
              ),
            ),
        ],
      ),
    );
  }
}

class _DestinationIcon extends StatelessWidget {
  const _DestinationIcon({required this.destination, required this.selected});

  final PlatformOwnerShellDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: destination.label,
      child: Icon(
        selected ? destination.selectedIcon : destination.icon,
        key: Key('platformOwnerNav${destination.name}Icon'),
      ),
    );
  }
}

class _PlatformOwnerHeader extends ConsumerWidget {
  const _PlatformOwnerHeader({required this.destination, required this.user});

  final PlatformOwnerShellDestination destination;
  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _shellSpacing,
        vertical: _headerVerticalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TestLabUz',
                  key: const Key('platformOwnerProductName'),
                  style: textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  destination.label,
                  key: const Key('platformOwnerPageTitle'),
                  style: textTheme.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Platform Owner',
                  key: const Key('platformOwnerRoleLabel'),
                  style: textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: _shellSpacing),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Current user: ${user.fullName}',
                    key: const Key('platformOwnerCurrentUser'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  key: const Key('entryLogoutButton'),
                  onPressed: () {
                    ref.read(authSessionControllerProvider.notifier).signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeutralPlatformOwnerShell extends StatelessWidget {
  const _NeutralPlatformOwnerShell();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}

class _PlatformOwnerShellUnavailable extends ConsumerWidget {
  const _PlatformOwnerShellUnavailable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(_shellSpacing),
            child: ConstrainedBox(
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
                  TextButton.icon(
                    key: const Key('entryLogoutButton'),
                    onPressed: () {
                      ref
                          .read(authSessionControllerProvider.notifier)
                          .signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
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
