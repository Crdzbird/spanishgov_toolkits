import 'dart:typed_data';


/// Well-known X.509 extension OID names.
const _extensionOidNames = <String, String>{
  '2.5.29.14': 'subjectKeyIdentifier',
  '2.5.29.15': 'keyUsage',
  '2.5.29.17': 'subjectAltName',
  '2.5.29.19': 'basicConstraints',
  '2.5.29.31': 'cRLDistributionPoints',
  '2.5.29.32': 'certificatePolicies',
  '2.5.29.35': 'authorityKeyIdentifier',
  '2.5.29.37': 'extKeyUsage',
  '1.3.6.1.5.5.7.1.1': 'authorityInfoAccess',
  '1.3.6.1.5.5.7.1.3': 'qcStatements',
};

/// A single X.509 certificate extension.
class X509Extension {
  /// Creates an [X509Extension].
  const X509Extension({
    required this.oid,
    required this.isCritical,
    required this.value,
  });

  /// The extension OID as a dot-separated string.
  final String oid;

  /// Whether this extension is marked as critical.
  final bool isCritical;

  /// The raw extension value bytes (the OCTET STRING content).
  final Uint8List value;

  /// Human-readable name for the extension OID, or the raw OID if unknown.
  String get name => _extensionOidNames[oid] ?? oid;

  @override
  String toString() => 'X509Extension($name, critical=$isCritical)';
}
