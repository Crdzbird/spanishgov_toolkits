import 'package:felectronic_clave/src/config/clave_config.dart';
import 'package:felectronic_clave/src/errors/clave_error.dart';
import 'package:felectronic_clave/src/models/clave_auth_method.dart';
import 'package:felectronic_clave/src/models/clave_auth_result.dart';
import 'package:felectronic_clave/src/models/clave_loa_level.dart';
import 'package:felectronic_clave/src/models/clave_mobile_session.dart';
import 'package:felectronic_clave/src/network/clave_http_client.dart';
import 'package:felectronic_clave/src/storage/clave_token_storage.dart';
import 'package:felectronic_clave/src/utils/jwt_parser.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

/// {@template clave_repository}
/// Cl@ve authentication repository.
///
/// Provides methods for authenticating via Spain's Cl@ve identity system
/// using OAuth/OIDC, managing tokens, and handling the Cl@ve Movil flow.
///
/// ```dart
/// final repo = ClaveRepository(config);
/// final result = await repo.login(method: ClaveAuthMethod.clavePin);
/// print(result.accessToken);
/// ```
/// {@endtemplate}
class ClaveRepository {
  /// {@macro clave_repository}
  ClaveRepository(
    this.config, {
    FlutterAppAuth? appAuth,
    ClaveTokenStorage? storage,
    ClaveHttpClient? httpClient,
  })  : _appAuth = appAuth ?? const FlutterAppAuth(),
        _storage = storage ?? ClaveTokenStorage(),
        _httpClient = httpClient ?? ClaveHttpClient();

  /// The Cl@ve configuration.
  final ClaveConfig config;
  final FlutterAppAuth _appAuth;
  final ClaveTokenStorage _storage;
  final ClaveHttpClient _httpClient;

  // ---------------------------------------------------------------------------
  // OAuth / OIDC
  // ---------------------------------------------------------------------------

  /// Authenticates via OAuth/OIDC with the specified Cl@ve [method].
  ///
  /// The [loa] parameter overrides [ClaveConfig.defaultLoa].
  /// For [ClaveAuthMethod.electronicCertificate], LOA is always set to
  /// [ClaveLoaLevel.medium].
  ///
  /// Returns a [ClaveAuthResult] on success.
  /// Throws [ClaveAuthCancelledError] if the user cancels the flow.
  /// Throws [ClaveDiscoveryFailedError] if the IDP is unreachable.
  Future<ClaveAuthResult> login({
    required ClaveAuthMethod method,
    ClaveLoaLevel? loa,
  }) async {
    final effectiveLoa = method == ClaveAuthMethod.electronicCertificate
        ? ClaveLoaLevel.medium
        : (loa ?? config.defaultLoa);

    try {
      final response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          config.clientId,
          config.redirectUri,
          clientSecret: config.clientSecret,
          discoveryUrl: config.discoveryUrl,
          scopes: ['openid'],
          additionalParameters: {
            'loa': '${effectiveLoa.value}',
            'idp': method.idpValue,
          },
        ),
      );

      final accessToken = response.accessToken;
      if (accessToken == null) {
        throw const ClaveUnknownError(
          'the token exchange succeeded but returned no access token',
        );
      }

      await _storage.saveAccessToken(accessToken);
      if (response.refreshToken != null) {
        await _storage.saveRefreshToken(response.refreshToken!);
      }

      return ClaveAuthResult(
        accessToken: accessToken,
        refreshToken: response.refreshToken,
        expiresIn: response.accessTokenExpirationDateTime
            ?.difference(DateTime.now())
            .inSeconds,
      );
    } on FlutterAppAuthUserCancelledException {
      throw const ClaveAuthCancelledError();
    } on PlatformException catch (e) {
      throw _mapAppAuthFailure(e);
    }
  }

  /// Turns an AppAuth platform failure into the closest [ClaveError].
  ///
  /// Cancellation is handled by its own catch clause; everything reaching here
  /// is a genuine failure. An earlier revision matched on
  /// `authorize_and_exchange_code_failed` and reported it as a cancellation —
  /// but that code is the *method name*, carried by every failure of that
  /// call, so a wrong client secret, an unreachable IDP and a rejected request
  /// all looked to the caller exactly like the user pressing Back.
  ClaveError _mapAppAuthFailure(PlatformException e) {
    final details =
        e is FlutterAppAuthPlatformException ? e.platformErrorDetails : null;

    // A failure to fetch the discovery document, or any transport-level
    // problem underneath it, means the IDP could not be reached.
    final text = [
      e.message ?? '',
      details?.errorDescription ?? '',
      details?.rootCauseDebugDescription ?? '',
      details?.errorDebugDescription ?? '',
      details?.domain ?? '',
    ].join(' ').toLowerCase();

    const unreachable = [
      'network',
      'discovery',
      'nsurlerrordomain',
      'unable to resolve host',
      'connection',
      'timed out',
      'timeout',
    ];
    if (unreachable.any(text.contains)) {
      return const ClaveDiscoveryFailedError();
    }

    // The authorization server answered and refused.
    final oauthError = details?.error;
    if (oauthError != null) {
      if (oauthError == FlutterAppAuthOAuthError.invalidClient ||
          oauthError == FlutterAppAuthOAuthError.unauthorizedClient ||
          oauthError == FlutterAppAuthOAuthError.invalidGrant) {
        return ClaveRefusedError(
          details?.errorDescription ??
              'the identity provider refused: '
                  '$oauthError',
        );
      }
      return ClaveUnknownError(
        details?.errorDescription ?? oauthError,
      );
    }

    return ClaveUnknownError(e.message ?? e.code);
  }

  /// Refreshes the access token using the stored refresh token.
  ///
  /// Returns the new access token, or `null` if refresh is not possible.
  /// On failure, clears stored tokens via [logout].
  Future<String?> refreshToken() async {
    final storedRefresh = await _storage.getRefreshToken();
    if (storedRefresh == null) return null;

    try {
      final response = await _appAuth.token(
        TokenRequest(
          config.clientId,
          config.redirectUri,
          clientSecret: config.clientSecret,
          issuer: config.issuerUrl,
          refreshToken: storedRefresh,
        ),
      );

      final newToken = response.accessToken;
      if (newToken != null) {
        await _storage.saveAccessToken(newToken);
        return newToken;
      }
      // A response with no token is not a rejection of the credential, so the
      // session is left in place for the next attempt.
      return null;
    } on PlatformException catch (e) {
      final failure = _mapAppAuthFailure(e);
      if (failure is ClaveDiscoveryFailedError) {
        // The IDP was unreachable. The refresh token has not been rejected,
        // so throwing the session away here would log a user out for a tunnel
        // or a flaky connection. Report the failure and keep the tokens.
        throw failure;
      }
      // The server answered and refused the refresh token: it is spent.
      await logout();
      return null;
    }
  }

  /// Returns the stored access token, or `null` if not set.
  Future<String?> getStoredToken() => _storage.getAccessToken();

  /// Validates the current token against the userInfo endpoint.
  ///
  /// Attempts to refresh first, then checks the userInfo endpoint.
  /// Returns the user info claims on success, or an empty map on failure.
  /// Clears tokens if the token is invalid.
  Future<Map<String, dynamic>> validateToken() async {
    final token = await refreshToken();
    if (token == null) return {};

    try {
      return await _httpClient.getUserInfo(
        url: config.userInfoUrl,
        accessToken: token,
      );
    } on ClaveNetworkException catch (e) {
      // Unreachable is not invalid. Keep the session and let the caller retry.
      throw ClaveDiscoveryFailedError(e.message);
    } on ClaveApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        // The token really was rejected.
        await logout();
        return {};
      }
      // 5xx and anything else is the server's problem, not the session's.
      throw ClaveUnknownError('userInfo failed with ${e.statusCode}');
    }
  }

  /// Extracts the NIF from the given JWT [token].
  String getNifFromToken(String token) => JwtParser.getNif(token);

  /// Logs out and clears all stored tokens.
  ///
  /// The local tokens are cleared even when the server cannot be told. A
  /// logout that leaves the session on the device because the network was
  /// down is not a logout — and since the remote call can now time out rather
  /// than hang, that case is reachable.
  Future<void> logout() async {
    final access = await _storage.getAccessToken();
    final refresh = await _storage.getRefreshToken();

    try {
      if (access != null || refresh != null) {
        await _httpClient.logout(
          url: config.logoutUrl,
          clientId: config.clientId,
          clientSecret: config.clientSecret,
          accessToken: access ?? '',
          refreshToken: refresh ?? '',
        );
      }
    } on Object {
      // Best effort: the token may outlive the device's copy of it, but the
      // device must not keep a session the user has ended.
    } finally {
      await _storage.deleteAccessToken();
      await _storage.deleteRefreshToken();
    }
  }

  // ---------------------------------------------------------------------------
  // Cl@ve Movil
  // ---------------------------------------------------------------------------

  /// Sends a Cl@ve Movil notification code for the given [document].
  ///
  /// - [document]: DNI (e.g. `12345678Z`) or NIE (e.g. `X1234567L`).
  /// - [contrast]: Validity date (`dd-MM-yyyy`) for DNI, or support number
  ///   (`C12345678` / `E12345678`) for NIE.
  ///
  /// Returns a [ClaveMobileSession] that can be used with
  /// [validateNotificationCode] to poll for user confirmation.
  ///
  /// Throws [ClaveInvalidContrastError] if the contrast doesn't match.
  /// Throws [ClaveRequestAlreadySentError] if a request is already pending.
  Future<ClaveMobileSession> sendNotificationCode({
    required String document,
    required String contrast,
  }) async {
    final createUrl = config.claveMobileCreateUrl;
    if (createUrl == null || createUrl.isEmpty) {
      throw const ClaveUnknownError(
        'Cl@ve Movil create URL not configured.',
      );
    }

    try {
      final response = await _httpClient.createNotificationCode(
        url: createUrl,
        clientId: config.clientId,
        clientSecret: config.clientSecret,
        document: document,
        contrast: contrast,
      );

      final token = _extractField(response, 'token_clave_movil');
      final verificationCode = _extractField(response, 'cod_verificacion');

      await _storage.saveDocument(document);

      return ClaveMobileSession(
        token: token,
        verificationCode: verificationCode,
        document: document,
      );
    } on Exception catch (e) {
      throw _mapClaveApiError(e);
    }
  }

  /// Polls for the result of a Cl@ve Movil notification.
  ///
  /// Returns a [ClaveAuthResult] when the user confirms on the Cl@ve app.
  /// Throws [ClaveIdleError] if the user hasn't responded yet (keep polling).
  /// Throws [ClaveSessionExpiredError] if the session timed out.
  /// Throws [ClaveRefusedError] if the user rejected the request.
  Future<ClaveAuthResult> validateNotificationCode({
    required ClaveMobileSession session,
  }) async {
    final validateUrl = config.claveMobileValidateUrl;
    if (validateUrl == null || validateUrl.isEmpty) {
      throw const ClaveUnknownError(
        'Cl@ve Movil validate URL not configured.',
      );
    }

    try {
      final response = await _httpClient.validateNotificationCode(
        url: validateUrl,
        clientId: config.clientId,
        clientSecret: config.clientSecret,
        nif: session.document,
        tokenClaveMovil: session.token,
      );

      final rawAccessToken = response['access_token'];
      final accessToken = rawAccessToken is String ? rawAccessToken : '';
      final rawRefreshToken = response['refresh_token'];
      final refreshTokenValue =
          rawRefreshToken is String ? rawRefreshToken : null;
      final rawExpiresIn = response['expires_in'];
      final expiresIn = rawExpiresIn is int ? rawExpiresIn : null;

      if (accessToken.isEmpty) {
        throw const ClaveIdleError();
      }

      await _storage.saveAccessToken(accessToken);
      if (refreshTokenValue != null) {
        await _storage.saveRefreshToken(refreshTokenValue);
      }

      return ClaveAuthResult(
        accessToken: accessToken,
        refreshToken: refreshTokenValue,
        expiresIn: expiresIn,
      );
    } on ClaveError {
      rethrow;
    } on Exception catch (e) {
      throw _mapClaveApiError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // LOA Elevation
  // ---------------------------------------------------------------------------

  /// Re-authenticates with a higher LOA level.
  ///
  /// Backs up current tokens before attempting the elevated login.
  /// If login fails, restores the previous tokens automatically.
  Future<ClaveAuthResult> elevateLoaLevel({
    required ClaveAuthMethod method,
    required ClaveLoaLevel loa,
  }) async {
    await _storage.backupTokens();

    try {
      final result = await login(method: method, loa: loa);
      // The elevated session stands on its own now. Leaving the backup behind
      // would let a later failed elevation restore this session's tokens long
      // after it ended.
      await _storage.clearBackup();
      return result;
    } on Object {
      await _storage.restoreBackup();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Releases resources held by the HTTP client.
  void dispose() => _httpClient.close();

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  String _extractField(Map<String, dynamic> response, String key) {
    // Try flat key first
    final flat = response[key];
    if (flat is String) return flat;
    // Try params list
    final params = response['params'];
    if (params is List) {
      for (final item in params) {
        if (item is Map && item['key'] == key) {
          final value = item['value'];
          if (value is String) return value;
        }
      }
    }
    return '';
  }

  ClaveError _mapClaveApiError(Exception e) {
    if (e is ClaveNetworkException) {
      return ClaveDiscoveryFailedError(e.message);
    }
    if (e is ClaveApiException) {
      switch (e.statusCode) {
        case 401:
          return const ClaveRefusedError();
        case 403:
          return const ClaveIdleError();
        case 408:
          return const ClaveSessionExpiredError();
        case 409:
          return const ClaveRequestAlreadySentError();
      }
      final body = e.body.toLowerCase();
      if (body.contains('expirado')) return const ClaveSessionExpiredError();
      if (body.contains('contraste')) {
        return const ClaveInvalidContrastError();
      }
      if (body.contains('ya existe') || body.contains('already')) {
        return const ClaveRequestAlreadySentError();
      }
    }

    return ClaveUnknownError(e.toString());
  }
}
