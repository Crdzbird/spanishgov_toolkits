import 'package:felectronic_certificates/felectronic_certificates.dart'
    as certs;
import 'package:felectronic_dnie_example/certificates/certificate_summary.dart';
import 'package:felectronic_dnie_example/certificates/password_dialog.dart';
import 'package:felectronic_dnie_example/shared/demo_status.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Getting a certificate into the app, which the other actions need: an app
/// can only use identities in its own keychain.
abstract final class CertificateImport {
  /// Imports the self-signed test certificate bundled with this app.
  static Future<DemoStatus> bundled() async {
    final file = await rootBundle.load('assets/test.p12');
    final session = await certs.AppleCertificates.importAndSelect(
      file.buffer.asUint8List(),
      password: 'test',
      alias: 'test.p12',
    );
    return DemoStatus(
      'Imported and selected ${session.certificate.displayName}',
      detail: (await certs.getAllCertificates()).summary,
    );
  }

  /// Imports a .p12 or .pfx the user picks.
  ///
  /// Every file type is offered, because iOS has no dependable type for
  /// PKCS#12 and a filtered picker shows the folder as empty.
  static Future<DemoStatus> picked(BuildContext context) async {
    final file = (await FilePicker.platform.pickFiles(
      withData: true,
    ))?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return const DemoStatus('Cancelled');
    final name = file.name.toLowerCase();
    if (!name.endsWith('.p12') && !name.endsWith('.pfx')) {
      return DemoStatus.error('Not a PKCS#12 file', 'Chosen: ${file.name}');
    }
    if (!context.mounted) return const DemoStatus('Cancelled');
    final password = await PasswordDialog.ask(context);
    if (password == null) return const DemoStatus('Cancelled');
    await certs.importCertificate(
      bytes,
      password: password.isEmpty ? null : password,
      alias: file.name,
    );
    final all = await certs.getAllCertificates();
    return DemoStatus('Imported ${file.name}', detail: all.summary);
  }
}
