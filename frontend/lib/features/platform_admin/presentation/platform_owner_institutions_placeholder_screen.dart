import 'package:flutter/material.dart';

import 'platform_owner_placeholder_body.dart';

class PlatformOwnerInstitutionsPlaceholderScreen extends StatelessWidget {
  const PlatformOwnerInstitutionsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlatformOwnerPlaceholderBody(
      key: Key('platformOwnerInstitutionsPlaceholder'),
      title: 'Institutions',
    );
  }
}
