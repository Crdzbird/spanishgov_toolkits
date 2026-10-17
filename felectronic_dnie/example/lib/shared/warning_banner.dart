import 'package:flutter/material.dart';

/// A banner for a problem that stops the tab from working, such as NFC
/// being switched off.
final class WarningBanner extends StatelessWidget {
  const factory WarningBanner({
    required IconData icon,
    required String message,
    Key? key,
  }) = WarningBanner._;

  const WarningBanner._({required this.icon, required this.message, super.key});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: ListTile(
        leading: Icon(icon, color: colors.onErrorContainer),
        title: Text(message, style: TextStyle(color: colors.onErrorContainer)),
      ),
    );
  }
}
