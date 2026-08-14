import 'package:flutter/material.dart';

const _placeholderPadding = 24.0;
const _placeholderMaxWidth = 720.0;

class InstitutionAdminDashboardPlaceholderScreen extends StatelessWidget {
  const InstitutionAdminDashboardPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InstitutionAdminPlaceholder(
      placeholderKey: Key('institutionAdminDashboardPlaceholder'),
      message: 'Institution dashboard will be implemented in S03-FE-002.',
    );
  }
}

class InstitutionAdminUsersPlaceholderScreen extends StatelessWidget {
  const InstitutionAdminUsersPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InstitutionAdminPlaceholder(
      placeholderKey: Key('institutionAdminUsersPlaceholder'),
      message: 'Institution user list will be implemented in S03-FE-004.',
    );
  }
}

class InstitutionAdminUserCreatePlaceholderScreen extends StatelessWidget {
  const InstitutionAdminUserCreatePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InstitutionAdminPlaceholder(
      placeholderKey: Key('institutionAdminUserCreatePlaceholder'),
      message: 'Institution user creation will be implemented in S03-FE-006.',
    );
  }
}

class InstitutionAdminUserDetailPlaceholderScreen extends StatelessWidget {
  const InstitutionAdminUserDetailPlaceholderScreen({
    required this.userId,
    super.key,
  });

  final String userId;

  @override
  Widget build(BuildContext context) {
    return const _InstitutionAdminPlaceholder(
      placeholderKey: Key('institutionAdminUserDetailPlaceholder'),
      message: 'Institution user details will be implemented in S03-FE-005.',
    );
  }
}

class InstitutionAdminInstitutionPlaceholderScreen extends StatelessWidget {
  const InstitutionAdminInstitutionPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InstitutionAdminPlaceholder(
      placeholderKey: Key('institutionAdminInstitutionPlaceholder'),
      message: 'Institution profile will be implemented in S03-FE-003.',
    );
  }
}

class InstitutionAdminSettingsPlaceholderScreen extends StatelessWidget {
  const InstitutionAdminSettingsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InstitutionAdminPlaceholder(
      placeholderKey: Key('institutionAdminSettingsPlaceholder'),
      message:
          'Assessment settings and understanding categories will be implemented in S03-FE-008 and S03-FE-009.',
    );
  }
}

class _InstitutionAdminPlaceholder extends StatelessWidget {
  const _InstitutionAdminPlaceholder({
    required this.placeholderKey,
    required this.message,
  });

  final Key placeholderKey;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(_placeholderPadding),
        child: ConstrainedBox(
          key: placeholderKey,
          constraints: const BoxConstraints(maxWidth: _placeholderMaxWidth),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
