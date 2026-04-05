import 'dart:typed_data';

import 'package:felectronic_x509/src/asn1/asn1_reader.dart';

/// Well-known public key algorithm OIDs.
const _pkAlgorithmOids = <String, String>{
  '1.2.840.113549.1.1.1': 'RSA',
  '1.2.840.10045.2.1': 'EC',
};

/// Well-known EC named curve OIDs and their bit sizes.
const _ecCurves = <String, int>{
  '1.2.840.10045.3.1.7': 256, // prime256v1 / P-256
  '1.3.132.0.34': 384, // secp384r1 / P-384
  '1.3.132.0.35': 521, // secp521r1 / P-521
};

/// Utility for extracting public key metadata from SubjectPublicKeyInfo.
abstract final class X509PublicKeyUtil {
  /// Return the algorithm name for a public key algorithm OID.
  static String algorithmName(String oid) => _pkAlgorithmOids[oid] ?? oid;

  /// Compute the key size in bits from the algorithm OID, optional parameter
  /// OID, and the raw key bytes.
  static int keySize({
    required String algorithmOid,
    required Uint8List keyBytes,
    String? parameterOid,
  }) {
    final name = _pkAlgorithmOids[algorithmOid];
    if (name == 'RSA') {
      return _rsaKeySize(keyBytes);
    }
    if (name == 'EC' && parameterOid != null) {
      return _ecCurves[parameterOid] ?? (keyBytes.length * 4);
    }
    // Fallback: estimate from byte count.
    return keyBytes.length * 8;
  }

  static int _rsaKeySize(Uint8List keyBytes) {
    // The BIT STRING content (minus unused-bits byte) is a DER SEQUENCE
    // containing the modulus INTEGER and the public exponent INTEGER.
    try {
      final reader = Asn1Reader(keyBytes);
      final seq = reader.readSequence();
      final modulus = seq.readInteger();
      return modulus.bitLength;
    } on Object {
      return keyBytes.length * 8;
    }
  }
}
