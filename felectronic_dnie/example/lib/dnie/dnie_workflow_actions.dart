import 'dart:convert';

import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:felectronic_dnie_example/shared/demo_status.dart';
import 'package:felectronic_dnie_example/shared/x509_summary.dart';

/// Actions that combine several card operations.
abstract final class DnieWorkflowActions {
  static Future<DemoStatus> parseCertificate(DnieSession session) async {
    final x509 = (await session.readCertificate()).parsedCertificate;
    if (x509 == null) return const DemoStatus.error('Could not parse it');
    return DemoStatus('X.509 v${x509.version}', detail: x509.summary);
  }

  static Future<DemoStatus> readiness(DnieSession session) async {
    final readiness = await session.checkReadiness();
    return DemoStatus(
      readiness.isReady ? 'Ready to sign' : 'Not ready',
      isError: !readiness.isReady,
      detail: [
        'NFC: ${readiness.nfcStatus.statusMessage}',
        'DNIe: ${readiness.isValidDnie}',
        'PIN: ${readiness.isPinCorrect}',
        if (readiness.error != null) readiness.error!.message,
      ].join('\n'),
    );
  }

  static Future<DemoStatus> identity(DnieSession session) async {
    final identity = await session.readFullIdentity();
    return DemoStatus(
      identity.personalData.displayName,
      detail:
          'NIF: ${identity.nif}\n'
          '${identity.certificateInfo.expiryStatus}',
    );
  }

  static Future<DemoStatus> probeAndSign(DnieSession session) async {
    final signed = await session.probeAndSign(utf8.encode('Probe and sign'));
    return DemoStatus(
      'Probed, then signed',
      detail: 'Signature: ${signed.signatureSizeBytes} bytes',
    );
  }

  static Future<DemoStatus> bothCertificates(DnieSession session) async {
    final signing = await session.signing.certificateDetails();
    final auth = await session.auth.certificateDetails();
    return DemoStatus(
      'Both certificates read',
      detail:
          'Signing: ${signing.expiryStatus}\n'
          'Authentication: ${auth.expiryStatus}',
    );
  }
}
