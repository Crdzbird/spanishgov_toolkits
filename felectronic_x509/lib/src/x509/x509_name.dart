
/// A mapping of well-known OIDs to their short names for distinguished name
/// attributes.
const _oidNames = <String, String>{
  '2.5.4.3': 'CN',
  '2.5.4.4': 'SN',
  '2.5.4.5': 'SERIALNUMBER',
  '2.5.4.6': 'C',
  '2.5.4.7': 'L',
  '2.5.4.8': 'ST',
  '2.5.4.9': 'STREET',
  '2.5.4.10': 'O',
  '2.5.4.11': 'OU',
  '2.5.4.12': 'T',
  '2.5.4.42': 'GN',
  '2.5.4.43': 'I',
  '2.5.4.46': 'dnQualifier',
  '1.2.840.113549.1.9.1': 'EMAIL',
  '0.9.2342.19200300.100.1.1': 'UID',
  '0.9.2342.19200300.100.1.25': 'DC',
};

/// An X.509 Distinguished Name comprised of attribute OID-value pairs.
///
/// Provides convenience getters for common attributes (CN, O, C, etc.) as well
/// as the raw [attributes] map keyed by OID.
class X509Name {
  /// Creates an [X509Name] from a map of OID strings to their values.
  const X509Name(this.attributes);

  /// Raw RDN attributes as OID -> value pairs.
  final Map<String, String> attributes;

  /// Common Name (CN) -- OID 2.5.4.3.
  String get commonName => attributes['2.5.4.3'] ?? '';

  /// Organization (O) -- OID 2.5.4.10.
  String get organization => attributes['2.5.4.10'] ?? '';

  /// Organizational Unit (OU) -- OID 2.5.4.11.
  String get organizationalUnit => attributes['2.5.4.11'] ?? '';

  /// Country (C) -- OID 2.5.4.6.
  String get country => attributes['2.5.4.6'] ?? '';

  /// State or Province (ST) -- OID 2.5.4.8.
  String get state => attributes['2.5.4.8'] ?? '';

  /// Locality (L) -- OID 2.5.4.7.
  String get locality => attributes['2.5.4.7'] ?? '';

  /// Serial Number -- OID 2.5.4.5 (e.g. NIF for Spanish DNIe).
  String get serialNumber => attributes['2.5.4.5'] ?? '';

  /// Email -- OID 1.2.840.113549.1.9.1.
  String get email => attributes['1.2.840.113549.1.9.1'] ?? '';

  /// Full distinguished name string (e.g. `"CN=..., O=..., C=..."`).
  String get distinguishedName => attributes.entries
      .map((e) => '${_oidToName(e.key)}=${e.value}')
      .join(', ');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is X509Name &&
          runtimeType == other.runtimeType &&
          _mapsEqual(attributes, other.attributes);

  @override
  int get hashCode => Object.hashAll(
        attributes.entries.map((e) => Object.hash(e.key, e.value)),
      );

  @override
  String toString() => distinguishedName;

  static String _oidToName(String oid) => _oidNames[oid] ?? oid;

  static bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
