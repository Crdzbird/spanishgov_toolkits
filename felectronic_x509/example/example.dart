// This is an example file; print statements are used for demonstration.
// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:felectronic_x509/felectronic_x509.dart';

void main() {
  // Example: parse a DER-encoded X.509 certificate.
  // Replace with actual certificate bytes.
  final derBytes = Uint8List(0);

  try {
    final cert = X509Parser.fromDer(derBytes);

    // Subject information
    print('Subject CN: ${cert.subject.commonName}');
    print('Subject O:  ${cert.subject.organization}');
    print('Subject C:  ${cert.subject.country}');

    // Issuer information
    print('Issuer CN: ${cert.issuer.commonName}');

    // Validity period
    print('Not before: ${cert.notValidBefore}');
    print('Not after:  ${cert.notValidAfter}');

    // Certificate metadata
    print('Version: v${cert.version}');
    print('Serial:  ${cert.serialNumber}');
    print('Algorithm: ${cert.signatureAlgorithm}');

    // Public key
    print('Key algorithm: ${cert.publicKeyAlgorithm}');
    print('Key size: ${cert.publicKeySize} bits');

    // Extensions
    for (final ext in cert.extensions) {
      print('Extension: ${ext.oid} (critical: ${ext.isCritical})');
    }
  } on FormatException catch (e) {
    print('Failed to parse certificate: $e');
  }
}
