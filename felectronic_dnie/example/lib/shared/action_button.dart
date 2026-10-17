import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:felectronic_dnie_example/shared/demo_status.dart';
import 'package:flutter/material.dart';

/// A button that runs [action] through [controller], showing [working]
/// while it runs. It is disabled while any action of the tab is running.
final class ActionButton extends StatelessWidget {
  const factory ActionButton({
    required DemoController controller,
    required IconData icon,
    required String label,
    required String working,
    required Future<DemoStatus> Function() action,
    String? hint,
    Key? key,
  }) = ActionButton._;

  const ActionButton._({
    required this.controller,
    required this.icon,
    required this.label,
    required this.working,
    required this.action,
    this.hint,
    super.key,
  });

  final DemoController controller;
  final IconData icon;
  final String label;
  final String working;
  final Future<DemoStatus> Function() action;
  final String? hint;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, status, _) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: status.busy ? null : () => controller.run(working, action),
        child: ListTile(
          enabled: !status.busy,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(label),
          subtitle: hint == null ? null : Text(hint!),
        ),
      ),
    ),
  );
}
