/// {@template cert_key_usage}
/// Key usage types for device-stored certificates.
/// {@endtemplate}
enum CertKeyUsage {
  /// The certificate can be used for digital signatures.
  signing('SIGNING'),

  /// The certificate can be used for authentication.
  authentication('AUTHENTICATION'),

  /// The certificate can be used for encryption.
  encryption('ENCRYPTION');

  const CertKeyUsage(this.value);

  /// The string value used in the Pigeon message layer.
  final String value;

  /// Parses a [CertKeyUsage] from its string [value].
  ///
  /// Returns `null` if no match is found.
  static CertKeyUsage? tryParse(String value) {
    final upper = value.toUpperCase();
    for (final usage in CertKeyUsage.values) {
      if (usage.value == upper) return usage;
    }
    return null;
  }

  /// Maps X.509 `keyUsage` extension flag names onto this enum.
  ///
  /// Expects the flag names produced by `X509Certificate.keyUsage`
  /// (`felectronic_x509`), which are the RFC 5280 spellings:
  ///
  /// | X.509 flag         | Result           |
  /// |--------------------|------------------|
  /// | `digitalSignature` | [authentication] |
  /// | `nonRepudiation`   | [signing]        |
  /// | `keyEncipherment`  | [encryption]     |
  /// | `dataEncipherment` | [encryption]     |
  ///
  /// Note the deliberate split: it is `nonRepudiation` — not
  /// `digitalSignature` — that maps to [signing], because a non-repudiable
  /// electronic signature requires that bit. `digitalSignature` alone only
  /// establishes [authentication]. This mirrors the mapping the Android and
  /// iOS layers applied previously, so behaviour is unchanged.
  ///
  /// Flags outside the table (`keyAgreement`, `keyCertSign`, `cRLSign`,
  /// `encipherOnly`, `decipherOnly`) are ignored. Duplicates collapse,
  /// first occurrence wins, input order is preserved.
  ///
  /// An empty result means the certificate carries no usages we model — it
  /// is **not** a licence to assume the certificate can sign.
  static List<CertKeyUsage> fromX509Flags(List<String> flags) {
    final result = <CertKeyUsage>[];
    for (final flag in flags) {
      final usage = switch (flag) {
        'digitalSignature' => authentication,
        'nonRepudiation' => signing,
        'keyEncipherment' || 'dataEncipherment' => encryption,
        _ => null,
      };
      if (usage != null && !result.contains(usage)) {
        result.add(usage);
      }
    }
    return result;
  }

  /// Parses a semicolon-separated usages string into a list of
  /// [CertKeyUsage] values.
  ///
  /// Unknown values are silently ignored.
  static List<CertKeyUsage> parseUsages(String usages) {
    if (usages.isEmpty) return [];
    return usages
        .split(';')
        .map((e) => tryParse(e.trim()))
        .whereType<CertKeyUsage>()
        .toList();
  }
}
