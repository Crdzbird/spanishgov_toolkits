import 'package:felectronic_clave/felectronic_clave.dart';

/// Cl@ve configuration for the example, pointing at a government gateway.
///
/// ## The pre-production environment is currently unavailable
///
/// Checked on 2026-08-20: every path under `auth-pre-api.redsara.es` answers
/// **503**, including the root, and `rtf-pre-api.redsara.es` refuses the
/// connection outright. So a `ClaveDiscoveryFailedError` from the default
/// configuration is the service being down, not a mistake in your setup.
///
/// Production is up — its discovery document advertises exactly the endpoints
/// derived below — but it needs a client registered for your own app, and it
/// authenticates real identities. The demo client id here is a pre-production
/// registration that production will not accept.
///
/// The practical consequence: **this example cannot complete a login as
/// shipped.** To run one, register a client and pass its details:
///
/// ```sh
/// flutter run \
///   --dart-define=CLAVE_ENV=pro \
///   --dart-define=CLAVE_CLIENT_ID=<your client> \
///   --dart-define=CLAVE_REDIRECT_URI=<your scheme>://login-callback \
///   --dart-define=CLAVE_CLIENT_SECRET=<if confidential>
/// ```
///
/// The redirect scheme must also be registered in `ios/Runner/Info.plist` and
/// in `android/app/build.gradle.kts`.
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

  /// What a caller should know before tapping login, in one sentence.
  ///
  /// The example cannot complete a login as shipped, and saying why up front
  /// is better than a failure several seconds later that reads as a bug.
  static String get readiness => _isPre
      ? 'Pointing at pre-production, which is currently returning 503 for '
            'every request — login will fail with a discovery error. See '
            'clave_config.dart for how to point this at your own client.'
      : hasClientSecret
      ? 'Pointing at production with a client secret.'
      : 'Pointing at production without a client secret. If your client is '
            'registered as confidential the token exchange will be refused; '
            'pass --dart-define=CLAVE_CLIENT_SECRET=…';

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
