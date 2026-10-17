import 'package:felectronic_dnie_example/shared/demo_controller.dart';
import 'package:flutter/material.dart';

/// The outcome of the last action, pinned below the tab so it stays visible
/// wherever the list is scrolled. [onStop] adds a button to cancel a running
/// action.
final class StatusPanel extends StatelessWidget {
  const factory StatusPanel({
    required DemoController controller,
    Future<void> Function()? onStop,
    Key? key,
  }) = StatusPanel._;

  const StatusPanel._({required this.controller, this.onStop, super.key});

  final DemoController controller;
  final Future<void> Function()? onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, status, _) => ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    if (status.busy)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        status.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: status.isError
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ),
                    ),
                    if (status.busy && onStop != null)
                      TextButton(onPressed: onStop, child: const Text('Stop')),
                  ],
                ),
                if (status.detail.isNotEmpty)
                  SelectableText(
                    status.detail,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
