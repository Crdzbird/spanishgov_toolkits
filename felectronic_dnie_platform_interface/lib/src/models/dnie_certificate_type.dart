/// {@template dnie_certificate_type}
/// The type of certificate to use on the DNIe.
///
/// The Spanish electronic DNIe contains two certificates:
/// - [sign] (FIRMA) — for non-repudiation digital signatures.
/// - [auth] (AUTENTICACION) — for identity authentication
///   (e.g. Cl@ve, Sede Electrónica).
/// {@endtemplate}
enum DnieCertificateType {
  /// Signing certificate (FIRMA) — for non-repudiation signatures.
  sign('SIGN'),

  /// Authentication certificate (AUTENTICACION) — for identity verification.
  auth('AUTH');

  /// {@macro dnie_certificate_type}
  const DnieCertificateType(this.value);

  /// The string value sent to the native platform (`'SIGN'` or `'AUTH'`).
  final String value;
}
