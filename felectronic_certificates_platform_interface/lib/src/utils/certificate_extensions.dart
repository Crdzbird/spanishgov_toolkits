import 'package:felectronic_certificates_platform_interface/src/models/cert_key_usage.dart';
import 'package:felectronic_certificates_platform_interface/src/models/device_certificate.dart';
import 'package:felectronic_x509/felectronic_x509.dart';

/// Convenience extensions on [DeviceCertificate].
extension DeviceCertificateX on DeviceCertificate {
  /// Whether the certificate has expired.
  bool get isExpired => expirationDate.isBefore(DateTime.now());

  /// Days remaining until expiration. Negative if expired.
  int get daysUntilExpiry =>
      expirationDate.difference(DateTime.now()).inDays;

  /// Whether the certificate expires within 30 days.
  bool get isExpiringSoon => !isExpired && daysUntilExpiry <= 30;

  /// Whether the certificate can be used for signing.
  bool get canSign => usages.contains(CertKeyUsage.signing);

  /// Whether the certificate can be used for authentication.
  bool get canAuthenticate => usages.contains(CertKeyUsage.authentication);

  /// Whether the certificate can be used for encryption.
  bool get canEncrypt => usages.contains(CertKeyUsage.encryption);

  /// Human-readable usage summary (e.g. "Signing, Authentication").
  String get usageSummary =>
      usages.map((u) => u.label).join(', ');

  /// Display name — alias if set, otherwise holder name.
  String get displayName => alias ?? holderName;

  /// Human-readable expiry status.
  String get expiryStatus {
    if (isExpired) return 'Expired';
    final days = daysUntilExpiry;
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    return 'Expires in $days days';
  }
}

/// Adds a display label to [CertKeyUsage].
extension CertKeyUsageLabel on CertKeyUsage {
  /// Human-readable label.
  String get label => switch (this) {
        CertKeyUsage.signing => 'Signing',
        CertKeyUsage.authentication => 'Authentication',
        CertKeyUsage.encryption => 'Encryption',
      };
}

/// Parses the full X.509 certificate from the DER-encoded [encoded] bytes.
extension DeviceCertificateParserX on DeviceCertificate {
  /// Parses the full X.509 certificate details from the raw DER bytes.
  ///
  /// Returns `null` if the certificate bytes are empty or malformed.
  X509Certificate? get parsed {
    if (encoded.isEmpty) return null;
    try {
      return X509Parser.fromDer(encoded);
    } on FormatException {
      return null;
    }
  }
}
