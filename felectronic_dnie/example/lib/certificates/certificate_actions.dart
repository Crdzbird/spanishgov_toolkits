import 'dart:convert';

import 'package:felectronic_certificates/felectronic_certificates.dart'
    as certs;
import 'package:felectronic_dnie_example/certificates/certificate_summary.dart';
import 'package:felectronic_dnie_example/shared/demo_status.dart';
import 'package:felectronic_dnie_example/shared/x509_summary.dart';
import 'package:flutter/material.dart';

/// Choosing, using and removing installed certificates.
abstract final class CertificateActions {
  static const _noDefault = DemoStatus.error(
    'No default certificate',
    'Select one first.',
  );

  static Future<DemoStatus> list() async {
    final all = await certs.getAllCertificates();
    return DemoStatus('${all.length} certificate(s)', detail: all.summary);
  }

  static Future<DemoStatus> pick(BuildContext context) async {
    final session = await certs.showCertificatePicker(context);
    if (session == null) return const DemoStatus('Nothing chosen');
    return DemoStatus(
      'Selected ${session.certificate.displayName}',
      detail: session.certificate.summary,
    );
  }

  static Future<DemoStatus> parseDefault() async {
    final x509 = (await certs.getDefaultCertificate())?.parsed;
    if (x509 == null) return _noDefault;
    return DemoStatus('X.509 v${x509.version}', detail: x509.summary);
  }

  static Future<DemoStatus> signWithDefault() async {
    final session = await certs.CertificateSession.fromDefault();
    if (session == null) return _noDefault;
    final signature = await session.sign(utf8.encode('Hello, certificate!'));
    return DemoStatus(
      'Signed with ${session.certificate.displayName}',
      detail: 'Signature: ${signature.length} bytes',
    );
  }

  static Future<DemoStatus> clearDefault() async {
    await certs.clearDefaultCertificate();
    return const DemoStatus('Default cleared');
  }

  static Future<DemoStatus> deleteDefault() async {
    await certs.deleteDefaultCertificate();
    return const DemoStatus('Default certificate deleted');
  }
}
