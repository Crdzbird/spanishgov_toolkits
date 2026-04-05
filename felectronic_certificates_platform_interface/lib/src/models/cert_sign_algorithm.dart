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

  /// The string value sent to the native platform.
  final String value;
}
