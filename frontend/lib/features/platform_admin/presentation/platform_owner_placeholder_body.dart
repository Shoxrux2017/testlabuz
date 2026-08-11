import 'package:flutter/material.dart';

class PlatformOwnerPlaceholderBody extends StatelessWidget {
  const PlatformOwnerPlaceholderBody({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          title,
          key: const Key('platformOwnerPlaceholderTitle'),
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
