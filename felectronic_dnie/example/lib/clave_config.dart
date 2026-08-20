import 'package:felectronic_clave/felectronic_clave.dart';

/// Cl@ve configuration for the example, pointing at a government gateway.
///
/// Defaults to **pre-production**. Note that the pre gateway is frequently
/// down — it answered 503 when this was last exercised — so a
/// `ClaveDiscoveryFailedError` here usually means the service is unavailable
/// rather than that anything is misconfigured. `curl` the discovery URL to
/// tell the two apart.
///
/// The endpoints, the client id and the redirect URI are the ones the Spanish
/// App Factory publishes with its own demo client, so this runs against a real
/// Cl@ve installation rather than a mock. It is pre-production: it issues real
/// tokens for test identities, and nothing here should be pointed at `auth-api`
/// (production) without a client registered for your own app.
///
/// ## The client secret is not in this file
///
/// The demo client is registered as confidential, so the gateway will refuse
/// the token exchange without its secret. It is deliberately not committed —
/// moving a credential into another repository is a decision for whoever owns
/// it, not a convenience. Supply it at run time:
///
/// ```sh
/// flutter run --dart-define=CLAVE_CLIENT_SECRET=<secret>
/// ```
///
/// The App Factory's own example carries the value if you need to look it up.
/// Every field below can be overridden the same way, so pointing this at your
/// own client registration needs no code change.
abstract final class ExampleClaveConfig {
  /// Which government environment to talk to: `pre` or `pro`.
  ///
  /// Defaults to pre-production. Production issues tokens for real identities
  /// and needs a client registered for your own app — the demo client id below
  /// is a pre-production registration and will not be accepted there.
  ///
  /// ```sh
  /// flutter run --dart-define=CLAVE_ENV=pro
  /// ```
  static const environment = String.fromEnvironment(
    'CLAVE_ENV',
    defaultValue: 'pre',
  );

  static bool get _isPre => environment != 'pro';

  /// The Keycloak realm, which carries discovery, userinfo, logout and the
  /// token endpoint that Cl@ve Movil validates against.
  static String get _realm => _isPre
      ? 'https://auth-pre-api.redsara.es/auth/realms/sgad-appfactory'
      : 'https://auth-api.redsara.es/auth/realms/sgad-appfactory';

  /// Creating a Cl@ve Movil notification is a separate service from the realm.
  static String get _mobileCreateUrl => _isPre
      ? 'https://rtf-pre-api.redsara.es'
            '/eapi-seguridad-clave-movil-api-pre/api/v1/claveMovil'
      : 'https://rtf-api.redsara.es'
            '/eapi-seguridad-clave-movil-api-prod/api/v1/claveMovil';

  /// The redirect URI. Its scheme must be registered in `Info.plist` and in
  /// `build.gradle.kts`, and must match what the client is registered with —
  /// a mismatch fails after the user has already authenticated.
  static const redirectUri = String.fromEnvironment(
    'CLAVE_REDIRECT_URI',
    defaultValue: 'com.auth0.example://login-callback',
  );

  /// The OAuth client id.
  static const clientId = String.fromEnvironment(
    'CLAVE_CLIENT_ID',
    defaultValue: 'e7cb008e-2428-4ad3-a583-e4c9d961a97f',
  );

  /// The client secret, empty unless supplied at build time.
  ///
  /// Empty means the client is treated as public, which is what RFC 8252 asks
  /// for and what this package prefers — but the demo registration is
  /// confidential, so leaving it empty will fail at the token exchange.
  static const clientSecret = String.fromEnvironment('CLAVE_CLIENT_SECRET');

  /// Whether a secret was supplied, so the UI can say why login will fail.
  static bool get hasClientSecret => clientSecret.isNotEmpty;

  /// The assembled configuration.
  static ClaveConfig get config => ClaveConfig(
    discoveryUrl: '$_realm/.well-known/openid-configuration',
    clientId: clientId,
    redirectUri: redirectUri,
    clientSecret: hasClientSecret ? clientSecret : null,
    userInfoUrl: '$_realm/protocol/openid-connect/userinfo',
    logoutUrl: '$_realm/protocol/openid-connect/logout',
    // Validation is the realm's ordinary token endpoint; creating the
    // notification is a separate service entirely.
    claveMobileValidateUrl: '$_realm/protocol/openid-connect/token',
    claveMobileCreateUrl: _mobileCreateUrl,
  );
}
