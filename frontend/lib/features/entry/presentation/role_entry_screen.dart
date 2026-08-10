import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/device/app_device_surface.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../auth/application/auth_session_state.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/domain/user_role.dart';

class RoleEntryScreen extends ConsumerWidget {
  const RoleEntryScreen({
    required this.expectedRole,
    required this.surface,
    super.key,
  });

  final UserRole expectedRole;
  final AppDeviceSurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionControllerProvider);
    final user = session.user;

    if (session.status != AuthSessionStatus.authenticated || user == null) {
      return const _NeutralEntryScreen();
    }

    if (user.role != expectedRole) {
      return const _EntryInvariantErrorScreen();
    }

    return _EntryScaffold(
      title: _roleTitle(expectedRole),
      user: user,
      surface: surface,
    );
  }
}

class UnsupportedDeviceScreen extends ConsumerWidget {
  const UnsupportedDeviceScreen({required this.surface, super.key});

  final AppDeviceSurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionControllerProvider);
    final user = session.user;

    if (session.status != AuthSessionStatus.authenticated || user == null) {
      return const _NeutralEntryScreen();
    }

    return _EntryScaffold(
      title: 'Unsupported device',
      user: user,
      surface: surface,
      message: 'This account is not supported on this device.',
      showInstitution: false,
    );
  }
}

class _EntryScaffold extends ConsumerWidget {
  const _EntryScaffold({
    required this.title,
    required this.user,
    required this.surface,
    this.message,
    this.showInstitution = true,
  });

  final String title;
  final AuthUser user;
  final AppDeviceSurface surface;
  final String? message;
  final bool showInstitution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final institution = user.institution;
    final shouldShowInstitution =
        showInstitution &&
        user.role != UserRole.platformOwner &&
        institution != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TestLabUz'),
        actions: [
          IconButton(
            key: const Key('entryLogoutButton'),
            tooltip: 'Sign out',
            onPressed: () {
              ref.read(authSessionControllerProvider.notifier).signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    key: const Key('entryRoleTitle'),
                    style: textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Current user: ${user.fullName}',
                    key: const Key('entryCurrentUser'),
                    textAlign: TextAlign.center,
                  ),
                  if (shouldShowInstitution) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Institution: ${institution.name}',
                      key: const Key('entryInstitutionName'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Device: ${surface.label}',
                    key: const Key('entryDeviceSurface'),
                    textAlign: TextAlign.center,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      message!,
                      key: const Key('entryMessage'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NeutralEntryScreen extends StatelessWidget {
  const _NeutralEntryScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}

class _EntryInvariantErrorScreen extends ConsumerWidget {
  const _EntryInvariantErrorScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
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

String _roleTitle(UserRole role) {
  return switch (role) {
    UserRole.platformOwner => 'Platform Owner',
    UserRole.institutionAdmin => 'Institution Admin',
    UserRole.teacher => 'Teacher',
    UserRole.student => 'Student',
    UserRole.parent => 'Parent',
  };
}
