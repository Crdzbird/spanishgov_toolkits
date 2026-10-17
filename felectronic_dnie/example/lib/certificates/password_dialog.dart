import 'package:flutter/material.dart';

part 'password_dialog_state.dart';

/// Asks for a PKCS#12 password. Pops with the text, or with null if the user
/// cancels.
final class PasswordDialog extends StatefulWidget {
  const factory PasswordDialog({Key? key}) = PasswordDialog._;

  const PasswordDialog._({super.key});

  /// Shows the dialog and returns what the user entered.
  static Future<String?> ask(BuildContext context) => showDialog<String>(
    context: context,
    builder: (_) => const PasswordDialog(),
  );

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}
