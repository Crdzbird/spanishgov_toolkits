import 'package:flutter/material.dart';

/// A heading between groups of actions.
final class SectionTitle extends StatelessWidget {
  const factory SectionTitle(String title, {Key? key}) = SectionTitle._;

  const SectionTitle._(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
