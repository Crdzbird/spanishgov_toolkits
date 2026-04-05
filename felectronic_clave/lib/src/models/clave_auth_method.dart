/// {@template clave_auth_method}
/// Authentication methods supported by the Spanish Cl@ve system.
/// {@endtemplate}
enum ClaveAuthMethod {
  /// Cl@ve PIN — temporary 24-hour PIN via SMS.
  clavePin('PIN24H'),

  /// Cl@ve Permanente — permanent password (Social Security).
  clavePermanente('SEGSOC'),

  /// Electronic certificate — client-side X.509 certificate (AFIRMA).
  electronicCertificate('AFIRMA'),

  /// European electronic credential (eIDAS / STORK).
  europeanCredential('EIDAS'),

  /// Cl@ve Movil — push notification to the Cl@ve app.
  claveMovil('CLVMOVIL');

  /// {@macro clave_auth_method}
  const ClaveAuthMethod(this.idpValue);

  /// The identity provider string sent to the Keycloak discovery endpoint.
  final String idpValue;
}
