import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:felectronic_dnie_example/shared/status_panel.dart';
import 'package:flutter/material.dart';

/// The layout every tab shares: a scrolling list of [children] above a
/// pinned [StatusPanel].
final class DemoTab extends StatelessWidget {
  const factory DemoTab({
    required DemoController controller,
    required List<Widget> children,
    Future<void> Function()? onStop,
    Key? key,
  }) = DemoTab._;

  const DemoTab._({
    required this.controller,
    required this.children,
    this.onStop,
    super.key,
  });

  final DemoController controller;
  final List<Widget> children;
  final Future<void> Function()? onStop;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: children,
        ),
      ),
      StatusPanel(controller: controller, onStop: onStop),
    ],
  );
}
