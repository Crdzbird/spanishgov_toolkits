import 'dart:convert';
import 'dart:typed_data';

import 'package:felectronic_x509/src/asn1/asn1_reader.dart';
import 'package:felectronic_x509/src/asn1/asn1_tag.dart';
import 'package:felectronic_x509/src/x509/x509_extension.dart';
import 'package:felectronic_x509/src/x509/x509_name.dart';

/// Well-known signature algorithm OIDs.
const _signatureAlgorithmNames = <String, String>{
  '1.2.840.113549.1.1.2': 'MD2withRSA',
  '1.2.840.113549.1.1.4': 'MD5withRSA',
  '1.2.840.113549.1.1.5': 'SHA1withRSA',
  '1.2.840.113549.1.1.11': 'SHA256withRSA',
  '1.2.840.113549.1.1.12': 'SHA384withRSA',
  '1.2.840.113549.1.1.13': 'SHA512withRSA',
  '1.2.840.113549.1.1.10': 'RSASSA-PSS',
  '1.2.840.10045.4.1': 'SHA1withECDSA',
  '1.2.840.10045.4.3.2': 'SHA256withECDSA',
  '1.2.840.10045.4.3.3': 'SHA384withECDSA',
  '1.2.840.10045.4.3.4': 'SHA512withECDSA',
};

/// Key usage bit flag labels, indexed by bit position.
const _keyUsageFlags = <String>[
  'digitalSignature',
  'nonRepudiation',
  'keyEncipherment',
  'dataEncipherment',
  'keyAgreement',
  'keyCertSign',
  'cRLSign',
  'encipherOnly',
  'decipherOnly',
];

/// Extended key usage OID names.
const _extKeyUsageNames = <String, String>{
  '1.3.6.1.5.5.7.3.1': 'serverAuth',
  '1.3.6.1.5.5.7.3.2': 'clientAuth',
  '1.3.6.1.5.5.7.3.3': 'codeSigning',
  '1.3.6.1.5.5.7.3.4': 'emailProtection',
  '1.3.6.1.5.5.7.3.8': 'timeStamping',
  '1.3.6.1.5.5.7.3.9': 'OCSPSigning',
};

/// A parsed X.509 certificate.
///
/// All fields are extracted from the DER-encoded structure. Use
/// `X509Parser` to create instances.
class X509Certificate {
  /// Creates an [X509Certificate] with all parsed fields.
  const X509Certificate({
    required this.version,
    required this.serialNumber,
    required this.signatureAlgorithm,
    required this.issuer,
    required this.subject,
    required this.notValidBefore,
    required this.notValidAfter,
    required this.publicKeyAlgorithm,
    required this.publicKeySize,
    required this.publicKeyBytes,
    required this.extensions,
    required this.signatureBytes,
    required this.tbsCertificateBytes,
    required this.derEncoded,
  });

  /// Certificate version (1, 2, or 3).
  final int version;

  /// Serial number as a hex string.
  final String serialNumber;

  /// Signature algorithm OID (e.g. `"1.2.840.113549.1.1.11"`).
  final String signatureAlgorithm;

  /// Issuer distinguished name.
  final X509Name issuer;

  /// Subject distinguished name.
  final X509Name subject;

  /// Validity start date.
  final DateTime notValidBefore;

  /// Validity end date.
  final DateTime notValidAfter;

  /// Public key algorithm name (e.g. `"RSA"`, `"EC"`).
  final String publicKeyAlgorithm;

  /// Public key size in bits.
  final int publicKeySize;

  /// Raw public key bytes.
  final Uint8List publicKeyBytes;

  /// Certificate extensions.
  final List<X509Extension> extensions;

  /// Signature bytes.
  final Uint8List signatureBytes;

  /// TBS (To Be Signed) certificate bytes for verification.
  final Uint8List tbsCertificateBytes;

  /// Original DER-encoded certificate bytes.
  ///
  /// Use these bytes with a crypto library to compute fingerprints
  /// (SHA-1, SHA-256, etc.).
  final Uint8List derEncoded;

  // ---------------------------------------------------------------------------
  // Computed properties
  // ---------------------------------------------------------------------------

  /// Human-readable signature algorithm name.
  String get signatureAlgorithmName =>
      _signatureAlgorithmNames[signatureAlgorithm] ?? signatureAlgorithm;

  /// Whether the certificate is currently within its validity period.
  bool get isCurrentlyValid {
    final now = DateTime.now().toUtc();
    return now.isAfter(notValidBefore) && now.isBefore(notValidAfter);
  }

  /// Whether the certificate has expired.
  bool get isExpired => DateTime.now().toUtc().isAfter(notValidAfter);

  /// Whether the certificate is self-signed (issuer equals subject).
  bool get isSelfSigned => issuer == subject;

  /// Days remaining until the certificate expires (negative if expired).
  int get daysUntilExpiry =>
      notValidAfter.difference(DateTime.now().toUtc()).inDays;

  // ---------------------------------------------------------------------------
  // Extension accessors
  // ---------------------------------------------------------------------------

  /// Key Usage flags (e.g. `["digitalSignature", "nonRepudiation"]`).
  List<String> get keyUsage {
    final ext = _findExtension('2.5.29.15');
    if (ext == null) return const [];
    try {
      final reader = Asn1Reader(ext.value);
      final obj = reader.readObject();
      if (obj.tag != Asn1Tag.bitString || obj.bytes.isEmpty) return const [];
      final unusedBits = obj.bytes[0];
      final flagBytes = Uint8List.sublistView(obj.bytes, 1);
      final flags = <String>[];
      for (var byteIndex = 0; byteIndex < flagBytes.length; byteIndex++) {
        for (var bit = 7; bit >= 0; bit--) {
          final bitIndex = byteIndex * 8 + (7 - bit);
          if (byteIndex == flagBytes.length - 1 &&
              (7 - bit) >= (8 - unusedBits) &&
              unusedBits > 0) {
            continue;
          }
          if (flagBytes[byteIndex] & (1 << bit) != 0 &&
              bitIndex < _keyUsageFlags.length) {
            flags.add(_keyUsageFlags[bitIndex]);
          }
        }
      }
      return flags;
    } on Object {
      return const [];
    }
  }

  /// Extended Key Usage OIDs (with human-readable names where known).
  List<String> get extendedKeyUsage {
    final ext = _findExtension('2.5.29.37');
    if (ext == null) return const [];
    try {
      final reader = Asn1Reader(ext.value);
      final seq = reader.readSequence();
      final usages = <String>[];
      while (seq.hasMore) {
        final oid = seq.readOid();
        usages.add(_extKeyUsageNames[oid] ?? oid);
      }
      return usages;
    } on Object {
      return const [];
    }
  }

  /// Subject Alternative Names (DNS names, emails, URIs).
  List<String> get subjectAltNames {
    final ext = _findExtension('2.5.29.17');
    if (ext == null) return const [];
    try {
      final reader = Asn1Reader(ext.value);
      final seq = reader.readSequence();
      final names = <String>[];
      while (seq.hasMore) {
        final obj = seq.readObject();
        if (obj.isContextTag) {
          final tag = obj.contextTagNumber;
          // 1 = rfc822Name, 2 = dNSName, 6 = URI
          if (tag == 1 || tag == 2 || tag == 6) {
            names.add(utf8.decode(obj.bytes, allowMalformed: true));
          }
        }
      }
      return names;
    } on Object {
      return const [];
    }
  }

  /// Whether this certificate is a Certificate Authority (from Basic
  /// Constraints).
  bool get isCA {
    final ext = _findExtension('2.5.29.19');
    if (ext == null) return false;
    try {
      final reader = Asn1Reader(ext.value);
      final seq = reader.readSequence();
      if (!seq.hasMore) return false;
      final obj = seq.readObject();
      if (obj.tag == Asn1Tag.boolean && obj.bytes.isNotEmpty) {
        return obj.bytes[0] != 0;
      }
      return false;
    } on Object {
      return false;
    }
  }

  /// CRL Distribution Point URLs.
  List<String> get crlDistributionPoints {
    final ext = _findExtension('2.5.29.31');
    if (ext == null) return const [];
    try {
      return _extractUrlsFromDistPoints(ext.value);
    } on Object {
      return const [];
    }
  }

  /// OCSP responder URLs (from Authority Information Access).
  List<String> get ocspUrls {
    final ext = _findExtension('1.3.6.1.5.5.7.1.1');
    if (ext == null) return const [];
    try {
      return _extractAiaUrls(ext.value, '1.3.6.1.5.5.7.48.1');
    } on Object {
      return const [];
    }
  }

  /// CA Issuer URLs (from Authority Information Access).
  List<String> get caIssuerUrls {
    final ext = _findExtension('1.3.6.1.5.5.7.1.1');
    if (ext == null) return const [];
    try {
      return _extractAiaUrls(ext.value, '1.3.6.1.5.5.7.48.2');
    } on Object {
      return const [];
    }
  }

  /// Certificate Policy OIDs.
  List<String> get certificatePolicies {
    final ext = _findExtension('2.5.29.32');
    if (ext == null) return const [];
    try {
      final reader = Asn1Reader(ext.value);
      final seq = reader.readSequence();
      final policies = <String>[];
      while (seq.hasMore) {
        final policySeq = seq.readSequence();
        policies.add(policySeq.readOid());
      }
      return policies;
    } on Object {
      return const [];
    }
  }

  /// Authority Key Identifier as a hex string, or `null` if absent.
  String? get authorityKeyIdentifier {
    final ext = _findExtension('2.5.29.35');
    if (ext == null) return null;
    try {
      final reader = Asn1Reader(ext.value);
      final seq = reader.readSequence();
      if (!seq.hasMore) return null;
      final obj = seq.readObject();
      // keyIdentifier is [0] implicit (tag 0x80).
      if (obj.isContextTag && obj.contextTagNumber == 0) {
        return _bytesToHex(obj.bytes);
      }
      return null;
    } on Object {
      return null;
    }
  }

  /// Subject Key Identifier as a hex string, or `null` if absent.
  String? get subjectKeyIdentifier {
    final ext = _findExtension('2.5.29.14');
    if (ext == null) return null;
    try {
      final reader = Asn1Reader(ext.value);
      final bytes = reader.readOctetString();
      return _bytesToHex(bytes);
    } on Object {
      return null;
    }
  }

  /// PEM-encoded certificate string.
  String get pem {
    final b64 = base64.encode(derEncoded);
    final lines = <String>['-----BEGIN CERTIFICATE-----'];
    for (var i = 0; i < b64.length; i += 64) {
      final end = i + 64 > b64.length ? b64.length : i + 64;
      lines.add(b64.substring(i, end));
    }
    lines.add('-----END CERTIFICATE-----');
    return lines.join('\n');
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  X509Extension? _findExtension(String oid) {
    for (final ext in extensions) {
      if (ext.oid == oid) return ext;
    }
    return null;
  }

  static List<String> _extractUrlsFromDistPoints(Uint8List value) {
    final urls = <String>[];
    final reader = Asn1Reader(value);
    final outerSeq = reader.readSequence();
    while (outerSeq.hasMore) {
      final dpSeq = outerSeq.readSequence();
      // distributionPoint is [0]
      final dpCtx = dpSeq.readContextTag(0);
      if (dpCtx == null) continue;
      // fullName is [0] inside distributionPoint
      final fullName = dpCtx.readContextTag(0);
      if (fullName == null) continue;
      while (fullName.hasMore) {
        final obj = fullName.readObject();
        // uniformResourceIdentifier is context [6]
        if (obj.isContextTag && obj.contextTagNumber == 6) {
          urls.add(utf8.decode(obj.bytes, allowMalformed: true));
        }
      }
    }
    return urls;
  }

  static List<String> _extractAiaUrls(Uint8List value, String targetOid) {
    final urls = <String>[];
    final reader = Asn1Reader(value);
    final seq = reader.readSequence();
    while (seq.hasMore) {
      final accessDesc = seq.readSequence();
      final oid = accessDesc.readOid();
      if (oid == targetOid) {
        final obj = accessDesc.readObject();
        if (obj.isContextTag && obj.contextTagNumber == 6) {
          urls.add(utf8.decode(obj.bytes, allowMalformed: true));
        }
      } else {
        accessDesc.skip();
      }
    }
    return urls;
  }

  static const _hexChars = '0123456789ABCDEF';

  static String _bytesToHex(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    // Pre-allocate: 2 hex chars per byte + 1 separator between each pair.
    final buf = StringBuffer();
    for (var i = 0; i < bytes.length; i++) {
      if (i > 0) buf.write(':');
      final b = bytes[i];
      buf
        ..write(_hexChars[(b >> 4) & 0xF])
        ..write(_hexChars[b & 0xF]);
    }
    return buf.toString();
  }

  @override
  String toString() =>
      'X509Certificate(subject=${subject.distinguishedName}, '
      'issuer=${issuer.distinguishedName}, '
      'serial=$serialNumber, '
      'valid=$notValidBefore..$notValidAfter)';
}
