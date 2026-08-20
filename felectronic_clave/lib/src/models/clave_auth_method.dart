import 'package:felectronic_clave/src/models/clave_loa_level.dart';

/// {@template clave_auth_method}
/// Authentication methods supported by the Spanish Cl@ve system.
///
/// The wire values are the `idp` parameter the Cl@ve gateway matches on. They
/// are the Spanish service's own spellings and must not be tidied.
/// {@endtemplate}
enum ClaveAuthMethod {
  /// Cl@ve PIN — temporary 24-hour PIN via SMS.
  ///
  /// Does not support [ClaveLoaLevel.high]; see [supportsLoa].
  clavePin('PIN24H'),

  /// Cl@ve Permanente — permanent password (Social Security).
  clavePermanente('SEGSOC'),

  /// Electronic certificate — client-side X.509 certificate (AFIRMA).
  ///
  /// Always authenticates at [ClaveLoaLevel.medium]; a caller cannot lower it.
  electronicCertificate('AFIRMA'),

  /// STORK — the original EU cross-border credential scheme.
  ///
  /// Kept distinct from [europeanCredential]: the gateway treats `STORK` and
  /// `EIDAS` as different identity providers, and the reference client offers
  /// both.
  stork('STORK'),

  /// European electronic credential (eIDAS).
  europeanCredential('EIDAS'),

  /// Cl@ve Movil — push notification to the Cl@ve app.
  claveMovil('CLVMOVIL');

  /// {@macro clave_auth_method}
  const ClaveAuthMethod(this.idpValue);

  /// The identity provider string sent as the `idp` parameter.
  final String idpValue;

  /// Whether this method can authenticate at [loa].
  ///
  /// Cl@ve PIN is a one-time code sent by SMS and does not reach the "high"
  /// level of assurance, which requires a qualified credential. Asking for it
  /// anyway produces a failure from the gateway rather than a downgrade, so
  /// `ClaveRepository.login` refuses the combination up front.
  bool supportsLoa(ClaveLoaLevel loa) =>
      !(this == ClaveAuthMethod.clavePin && loa == ClaveLoaLevel.high);
}
