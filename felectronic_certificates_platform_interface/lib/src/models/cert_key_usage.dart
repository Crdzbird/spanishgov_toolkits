/// Key usage types for device-stored certificates.
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
