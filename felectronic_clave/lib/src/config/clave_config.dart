import 'package:felectronic_clave/src/models/clave_auth_method.dart';
import 'package:felectronic_clave/src/models/clave_loa_level.dart';
import 'package:flutter/foundation.dart';

/// {@template clave_config}
/// Configuration for the Cl@ve authentication service.
///
/// Provides the OAuth/OIDC endpoints, client credentials,
/// and the set of authentication methods available to users.
///
/// ```dart
/// final config = ClaveConfig(
///   discoveryUrl: 'https://auth-api.redsara.es/auth/realms/.../.well-known/openid-configuration',
///   clientId: 'my-client-id',
///   redirectUri: 'com.example.app://login-callback',
///   clientSecret: 'my-client-secret',
///   userInfoUrl: 'https://auth-api.redsara.es/auth/realms/.../protocol/openid-connect/userinfo',
///   logoutUrl: 'https://auth-api.redsara.es/auth/realms/.../protocol/openid-connect/logout',
/// );
/// ```
/// {@endtemplate}
@immutable
class ClaveConfig {
  /// {@macro clave_config}
  const ClaveConfig({
    required this.discoveryUrl,
    required this.clientId,
    required this.redirectUri,
    required this.userInfoUrl,
    required this.logoutUrl,
    this.clientSecret,
    this.defaultLoa = ClaveLoaLevel.low,
    this.enabledMethods = const [
      ClaveAuthMethod.clavePin,
      ClaveAuthMethod.clavePermanente,
      ClaveAuthMethod.electronicCertificate,
      ClaveAuthMethod.claveMovil,
    ],
    this.claveMobileCreateUrl,
    this.claveMobileValidateUrl,
    this.preferEphemeralSession = true,
    this.promptLogin = true,
    this.allowInsecureConnections = false,
  });

  /// OpenID Connect discovery endpoint URL.
  final String discoveryUrl;

  /// OAuth 2.0 client identifier.
  final String clientId;

  /// OAuth 2.0 redirect URI (must match native app configuration).
  final String redirectUri;

  /// OAuth 2.0 client secret, when the client is registered as confidential.
  ///
  /// Leave this null for a public client. A mobile app cannot keep a secret —
  /// anyone can extract it from the distributed binary — so RFC 8252 says a
  /// native app should be registered as a public client and rely on PKCE,
  /// which `flutter_appauth` performs automatically.
  ///
  /// It stays configurable because some Cl@ve deployments register their
  /// clients as confidential and reject a request without it. If yours does,
  /// know that the secret is not actually secret, and that the security of the
  /// flow rests on PKCE and the redirect URI rather than on it.
  final String? clientSecret;

  /// UserInfo endpoint for token validation.
  final String userInfoUrl;

  /// Logout endpoint.
  final String logoutUrl;

  /// Default Level of Assurance for login requests.
  final ClaveLoaLevel defaultLoa;

  /// Authentication methods available to the user.
  final List<ClaveAuthMethod> enabledMethods;

  /// Cl@ve Movil notification creation endpoint.
  ///
  /// Required only if [ClaveAuthMethod.claveMovil] is enabled.
  final String? claveMobileCreateUrl;

  /// Cl@ve Movil token validation endpoint.
  ///
  /// Required only if [ClaveAuthMethod.claveMovil] is enabled.
  final String? claveMobileValidateUrl;

  /// Whether the login browser runs as an ephemeral session.
  ///
  /// Maps to `ExternalUserAgent.ephemeralAsWebAuthenticationSession`.
  ///
  /// On iOS this is what makes the flow a genuine *web authentication*
  /// session: `ASWebAuthenticationSession` starts with no access to Safari's
  /// cookies, so the government gateway cannot see — or leave behind — a
  /// browser session belonging to the rest of the device. It also suppresses
  /// the system consent prompt that otherwise appears before the browser
  /// opens.
  ///
  /// Defaults to true, matching the reference client. Turning it off means an
  /// existing Cl@ve session in Safari is reused, which is convenient and is
  /// also how one user's session can be handed to whoever next opens the app.
  final bool preferEphemeralSession;

  /// Whether to force re-authentication by sending `prompt=login`.
  ///
  /// Without it the gateway may answer from an existing session and return a
  /// token without the user proving anything. That matters most when raising
  /// the level of assurance, where the whole point is to make the user
  /// authenticate again more strongly.
  ///
  /// Defaults to true, matching the reference client.
  final bool promptLogin;

  /// Whether to permit plain HTTP and untrusted certificates.
  ///
  /// **Never enable this in a shipped build.** It disables transport security
  /// for the authentication exchange, which is the one exchange in this
  /// package that carries credentials. It exists because government test and
  /// development gateways are reachable only over self-signed TLS.
  ///
  /// Defaults to false.
  final bool allowInsecureConnections;

  /// Extracts the OAuth issuer URL from [discoveryUrl] by stripping
  /// the `.well-known/openid-configuration` suffix.
  String get issuerUrl =>
      discoveryUrl.replaceAll('/.well-known/openid-configuration', '');
}
