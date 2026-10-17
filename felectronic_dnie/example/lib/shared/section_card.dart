import 'package:flutter/material.dart';

/// A card that stacks its [children] with even spacing.
final class SectionCard extends StatelessWidget {
  const factory SectionCard({
    required List<Widget> children,
    Key? key,
  }) = SectionCard._;

  const SectionCard._({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: children,
      ),
    ),
  );
}
