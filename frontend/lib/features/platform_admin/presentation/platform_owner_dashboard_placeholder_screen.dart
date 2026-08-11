import 'package:flutter/material.dart';

import 'platform_owner_placeholder_body.dart';

class PlatformOwnerDashboardPlaceholderScreen extends StatelessWidget {
  const PlatformOwnerDashboardPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlatformOwnerPlaceholderBody(
      key: Key('platformOwnerDashboardPlaceholder'),
      title: 'Dashboard',
    );
  }
}
