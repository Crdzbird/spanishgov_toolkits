part of 'password_dialog.dart';

final class _PasswordDialogState extends State<PasswordDialog> {
  final _password = TextEditingController();

  void _submit() => Navigator.of(context).pop(_password.text);

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('PKCS#12 password'),
    content: TextField(
      controller: _password,
      autofocus: true,
      obscureText: true,
      decoration: const InputDecoration(
        hintText: 'Leave empty if the file is not encrypted',
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Import')),
    ],
  );
}
