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
    required this.clientSecret,
    required this.userInfoUrl,
    required this.logoutUrl,
    this.defaultLoa = ClaveLoaLevel.low,
    this.enabledMethods = const [
      ClaveAuthMethod.clavePin,
      ClaveAuthMethod.clavePermanente,
      ClaveAuthMethod.electronicCertificate,
      ClaveAuthMethod.claveMovil,
    ],
    this.claveMobileCreateUrl,
    this.claveMobileValidateUrl,
  });

  /// OpenID Connect discovery endpoint URL.
  final String discoveryUrl;

  /// OAuth 2.0 client identifier.
  final String clientId;

  /// OAuth 2.0 redirect URI (must match native app configuration).
  final String redirectUri;

  /// OAuth 2.0 client secret.
  final String clientSecret;

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

  /// Extracts the OAuth issuer URL from [discoveryUrl] by stripping
  /// the `.well-known/openid-configuration` suffix.
  String get issuerUrl =>
      discoveryUrl.replaceAll('/.well-known/openid-configuration', '');
}
