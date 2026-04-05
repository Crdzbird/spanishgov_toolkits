/// {@template clave_loa_level}
/// Level of Assurance for Cl@ve authentication.
///
/// Higher levels require stronger identity verification.
/// {@endtemplate}
enum ClaveLoaLevel {
  /// Basic assurance — password or PIN-based.
  low(1),

  /// Substantial assurance — two-factor or certificate-based.
  medium(2),

  /// High assurance — qualified electronic signature or certificate.
  high(3);

  /// {@macro clave_loa_level}
  const ClaveLoaLevel(this.value);

  /// The integer value sent to the identity provider.
  final int value;
}
