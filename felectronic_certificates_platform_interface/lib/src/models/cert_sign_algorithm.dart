import 'package:felectronic_certificates_platform_interface/src/generated/messages.g.dart';

/// {@template cert_sign_algorithm}
/// Signing algorithms supported for certificate-based signatures.
/// {@endtemplate}
enum CertSignAlgorithm {
  /// SHA-256 with RSA.
  sha256rsa('SHA256RSA'),

  /// SHA-384 with RSA.
  sha384rsa('SHA384RSA'),

  /// SHA-512 with RSA.
  sha512rsa('SHA512RSA'),

  /// SHA-256 with ECDSA.
  sha256ec('SHA256EC'),

  /// SHA-384 with ECDSA.
  sha384ec('SHA384EC'),

  /// SHA-512 with ECDSA.
  sha512ec('SHA512EC');

  const CertSignAlgorithm(this.value);

  /// The legacy string spelling of this algorithm.
  ///
  /// No longer used to cross the platform boundary — that is now a typed
  /// enum. Retained because the Android AAR's signing API still takes this
  /// form, and it is useful for logging.
  final String value;

  /// The wire representation sent to the native platform.
  ///
  /// Exhaustive with no default branch, so adding a case here without adding
  /// one to the Pigeon schema is a compile error rather than a silent
  /// fallback to SHA-256/RSA.
  CertSignAlgorithmMessage get wire => switch (this) {
    CertSignAlgorithm.sha256rsa => CertSignAlgorithmMessage.sha256rsa,
    CertSignAlgorithm.sha384rsa => CertSignAlgorithmMessage.sha384rsa,
    CertSignAlgorithm.sha512rsa => CertSignAlgorithmMessage.sha512rsa,
    CertSignAlgorithm.sha256ec => CertSignAlgorithmMessage.sha256ec,
    CertSignAlgorithm.sha384ec => CertSignAlgorithmMessage.sha384ec,
    CertSignAlgorithm.sha512ec => CertSignAlgorithmMessage.sha512ec,
  };
}
