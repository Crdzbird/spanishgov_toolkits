import 'package:felectronic_clave/felectronic_clave.dart';

/// Cl@ve configuration for the example, pointing at a government gateway.
///
/// It cannot complete a login as shipped. Pre-production answers 503 to
/// everything, and production rejects the App Factory demo client, which is
/// a pre-production registration. To run a login, register a client and pass
/// its details at build time:
///
/// ```sh
/// flutter run \
///   --dart-define=CLAVE_ENV=pro \
///   --dart-define=CLAVE_CLIENT_ID=<your client> \
///   --dart-define=CLAVE_REDIRECT_URI=<your scheme>://login-callback \
///   --dart-define=CLAVE_CLIENT_SECRET=<only if confidential>
/// ```
///
/// The redirect scheme must also be registered in `ios/Runner/Info.plist` and
/// `android/app/build.gradle.kts`. No secret is committed here.
abstract final class ExampleClaveConfig {
  /// `pro` (the default) or `pre`. Production signs in real people.
  static const environment = String.fromEnvironment(
    'CLAVE_ENV',
    defaultValue: 'pro',
  );

  static bool get _isPre => environment != 'pro';

  /// The Keycloak realm: discovery, userinfo, logout, and the token endpoint
  /// Cl@ve Movil validates against.
  static String get _realm => _isPre
      ? 'https://auth-pre-api.redsara.es/auth/realms/sgad-appfactory'
      : 'https://auth-api.redsara.es/auth/realms/sgad-appfactory';

  /// Creating a Cl@ve Movil notification is a separate service.
  static String get _mobileCreateUrl => _isPre
      ? 'https://rtf-pre-api.redsara.es'
            '/eapi-seguridad-clave-movil-api-pre/api/v1/claveMovil'
      : 'https://rtf-api.redsara.es'
            '/eapi-seguridad-clave-movil-api-prod/api/v1/claveMovil';

  /// Must match the client registration and the schemes registered with
  /// both platforms, or the login fails after the user has authenticated.
  static const redirectUri = String.fromEnvironment(
    'CLAVE_REDIRECT_URI',
    defaultValue: 'com.auth0.example://login-callback',
  );

  /// The App Factory demo client, registered against pre-production only.
  static const _demoClientId = 'e7cb008e-2428-4ad3-a583-e4c9d961a97f';

  /// The OAuth client id.
  static const clientId = String.fromEnvironment(
    'CLAVE_CLIENT_ID',
    defaultValue: _demoClientId,
  );

  /// The client secret. Empty means a public client, which RFC 8252 prefers;
  /// the demo client is confidential, so it fails without one.
  static const clientSecret = String.fromEnvironment('CLAVE_CLIENT_SECRET');

  /// Why a login will or will not work, before anyone taps one.
  static String get readiness {
    if (_isPre) {
      return 'Pointing at pre-production, which answers 503 to every request, '
          'so login fails with a discovery error.';
    }
    if (clientId == _demoClientId) {
      return 'Pointing at production with the pre-production demo client, '
          'which production rejects. Pass --dart-define=CLAVE_CLIENT_ID.';
    }
    return 'Pointing at production as a '
        '${clientSecret.isEmpty ? 'public' : 'confidential'} client. '
        'A login here signs in a real person.';
  }

  /// The assembled configuration.
  static ClaveConfig get config => ClaveConfig(
    discoveryUrl: '$_realm/.well-known/openid-configuration',
    clientId: clientId,
    redirectUri: redirectUri,
    clientSecret: clientSecret.isEmpty ? null : clientSecret,
    userInfoUrl: '$_realm/protocol/openid-connect/userinfo',
    logoutUrl: '$_realm/protocol/openid-connect/logout',
    claveMobileValidateUrl: '$_realm/protocol/openid-connect/token',
    claveMobileCreateUrl: _mobileCreateUrl,
  );
}
