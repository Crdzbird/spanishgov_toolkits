import 'dart:convert';
import 'dart:typed_data';

import 'package:felectronic_dnie_platform_interface/src/models/signed_data.dart';
import 'package:felectronic_x509/felectronic_x509.dart';

/// Convenience extensions on [SignedData].
extension SignedDataX on SignedData {
  /// Whether the signed data bytes are present.
  bool get hasSignature => signedData.isNotEmpty;

  /// Whether the certificate string is present.
  bool get hasCertificate => certificate.isNotEmpty;

  /// Whether both signature and certificate are present.
  bool get isComplete => hasSignature && hasCertificate;

  /// The size of the signature in bytes.
  int get signatureSizeBytes => signedData.length;

  /// The DER bytes of [certificate], or `null` if it is empty or not valid
  /// Base64.
  Uint8List? get certificateDer {
    if (certificate.isEmpty) return null;
    try {
      return base64Decode(certificate);
    } on FormatException {
      return null;
    }
  }

  /// Parses the full X.509 certificate from the base64-encoded
  /// [certificate] string.
  ///
  /// Returns `null` if the certificate is empty or malformed.
  X509Certificate? get parsedCertificate {
    if (certificate.isEmpty) return null;
    try {
      return X509Parser.fromBase64(certificate);
    } on FormatException {
      return null;
    }
  }
}
