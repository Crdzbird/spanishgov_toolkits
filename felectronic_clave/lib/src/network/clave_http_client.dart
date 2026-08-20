import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// {@template clave_http_client}
/// HTTP client for the Cl@ve REST endpoints.
///
/// Covers the Cl@ve Movil notification API, the userInfo endpoint and logout.
/// The OAuth authorization and token exchange are not performed here — those
/// go through `flutter_appauth`, which owns the browser session and PKCE.
///
/// Every request is bounded by [timeout]. Without one a stalled socket hangs
/// forever, and the polling timeout in `ClaveMobilePoller` — which can only be
/// checked between requests — would never be reached.
/// {@endtemplate}
class ClaveHttpClient {
  /// Creates a client with an optional custom [client] and request [timeout].
  ClaveHttpClient([
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  ]) : _client = client ?? http.Client();

  final http.Client _client;

  /// How long any single request may take before it is abandoned.
  final Duration timeout;

  /// Creates a Cl@ve Movil notification code.
  ///
  /// Returns the raw JSON response body as a map.
  ///
  /// The body is a **key/value envelope**, not a flat object:
  ///
  /// ```json
  /// {"params":[{"key":"doc","value":"..."},
  ///            {"key":"contraste","value":"..."}]}
  /// ```
  ///
  /// An earlier revision sent `{"doc":...,"contraste":...}`, which this
  /// endpoint does not accept. The credentials go in the *headers* here, and
  /// in the *body* on the validate call — the two endpoints are different
  /// services and genuinely disagree.
  Future<Map<String, dynamic>> createNotificationCode({
    required String url,
    required String clientId,
    required String document,
    required String contrast,
    String? clientSecret,
  }) =>
      _postJson(
        url,
        {
          'Content-Type': 'application/json',
          'client_id': clientId,
          if (clientSecret != null) 'client_secret': clientSecret,
        },
        ClaveKeyValues.envelope({
          ClaveKeyValues.document: document,
          ClaveKeyValues.contrast: contrast,
        }),
      );

  /// Validates a Cl@ve Movil notification code (polls for user approval).
  ///
  /// Returns the raw JSON response body as a map.
  Future<Map<String, dynamic>> validateNotificationCode({
    required String url,
    required String clientId,
    required String nif,
    required String tokenClaveMovil,
    String? clientSecret,
  }) =>
      _postForm(
        url,
        {
          'grant_type': 'password',
          'nif': nif,
          'token_clave_movil': tokenClaveMovil,
          'idp': 'AEAT',
          'client_id': clientId,
          if (clientSecret != null) 'client_secret': clientSecret,
        },
      );

  /// Reads the userInfo endpoint for the given [accessToken].
  ///
  /// Throws [ClaveApiException] when the endpoint answers with a non-2xx
  /// status. An earlier revision returned an empty map instead, which made a
  /// rejected token (401) and a server outage (503) indistinguishable — and
  /// the caller logged the user out for both.
  Future<Map<String, dynamic>> getUserInfo({
    required String url,
    required String accessToken,
  }) =>
      _getJson(url, {'Authorization': 'Bearer $accessToken'});

  /// Posts a logout request. Returns whether the server accepted it.
  ///
  /// The access token authenticates the call as a bearer header; the body
  /// names the session to end. An earlier revision sent the access token as a
  /// `token` form field with no header, which is a different request.
  Future<bool> logout({
    required String url,
    required String clientId,
    required String accessToken,
    required String refreshToken,
    String? clientSecret,
  }) async {
    final response = await _send(
      () => _client.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': clientId,
          if (clientSecret != null) 'client_secret': clientSecret,
          'refresh_token': refreshToken,
        },
      ),
    );
    return _isSuccess(response.statusCode);
  }

  Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, String> headers,
    Map<String, Object?> body,
  ) async {
    final response = await _send(
      () => _client.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _postForm(
    String url,
    Map<String, String> body,
  ) async {
    final response = await _send(
      () => _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _getJson(
    String url,
    Map<String, String> headers,
  ) async {
    final response = await _send(
      () => _client.get(Uri.parse(url), headers: headers),
    );
    return _decode(response);
  }

  /// Runs a request under [timeout], turning transport failures into
  /// [ClaveNetworkException] so a caller can tell "unreachable" from
  /// "rejected".
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw ClaveNetworkException('the request timed out after $timeout');
    } on SocketException catch (e) {
      throw ClaveNetworkException(e.message);
    } on http.ClientException catch (e) {
      throw ClaveNetworkException(e.message);
    }
  }

  static bool _isSuccess(int status) => status >= 200 && status < 300;

  /// Decodes a successful JSON body, or maps the response to an exception.
  ///
  /// Any 2xx is accepted, not only 200 — a creation endpoint answering 201 is
  /// a success, and the previous strict check reported it as a failure.
  Map<String, dynamic> _decode(http.Response response) {
    if (!_isSuccess(response.statusCode)) {
      throw _mapHttpError(response);
    }
    if (response.body.isEmpty) return {};
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException catch (e) {
      throw ClaveApiException(
        response.statusCode,
        'expected JSON but could not parse it: ${e.message}',
      );
    }
  }

  /// Extracts the server's own message from a failure body.
  ///
  /// The two Cl@ve Movil endpoints are different services and report failures
  /// differently. The notification API answers
  /// `{"messages":[{"details":"..."}]}`, while validation goes to Keycloak,
  /// which answers `{"error":"...","error_description":"..."}`. An earlier
  /// revision read only the first shape, so every failure from the validate
  /// endpoint arrived as an unparsed blob and could not be classified.
  ClaveApiException _mapHttpError(http.Response response) {
    final body = response.body;
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        final messages = json['messages'];
        if (messages is List && messages.isNotEmpty) {
          final first = messages.first;
          final details = first is Map ? first['details'] as String? : null;
          if (details != null) {
            return ClaveApiException(response.statusCode, details);
          }
        }
        final description = json['error_description'];
        if (description is String) {
          return ClaveApiException(response.statusCode, description);
        }
      }
    } on Object {
      // Not JSON — use status code only.
    }
    return ClaveApiException(response.statusCode, body);
  }

  /// Releases the underlying HTTP client.
  void close() => _client.close();
}

/// The key/value envelope the Cl@ve Movil notification API speaks.
///
/// Both its requests and its responses carry a `params` list of
/// `{"key":..., "value":...}` pairs rather than a plain object.
abstract final class ClaveKeyValues {
  /// The document (DNI or NIE) being authenticated.
  static const document = 'doc';

  /// The contrast datum: a validity date for a DNI, a support number for a
  /// NIE.
  static const contrast = 'contraste';

  /// The session token returned by the create call, replayed on validation.
  static const mobileToken = 'token_clave_movil';

  /// The code shown to the user so they can confirm they are approving the
  /// request they started, and not somebody else's.
  static const verificationCode = 'cod_verificacion';

  /// Wraps [values] into the `params` envelope.
  static Map<String, Object?> envelope(Map<String, String> values) => {
        'params': [
          for (final entry in values.entries)
            {'key': entry.key, 'value': entry.value},
        ],
      };

  /// Reads [key] out of an envelope, tolerating a flat object too.
  ///
  /// Returns an empty string when the key is absent, which the caller treats
  /// as "the service did not give us one".
  static String read(Map<String, dynamic> response, String key) {
    final flat = response[key];
    if (flat is String) return flat;
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
}

/// {@template clave_api_exception}
/// Thrown when a Cl@ve HTTP request returns a non-2xx status code.
/// {@endtemplate}
class ClaveApiException implements Exception {
  /// Creates a [ClaveApiException] with the given [statusCode] and [body].
  const ClaveApiException(this.statusCode, this.body);

  /// The HTTP status code of the response.
  final int statusCode;

  /// The response body, or the error detail extracted from it.
  ///
  /// This can carry whatever the server chose to send back. Treat it as
  /// diagnostic material rather than something to show a user or write to a
  /// log that leaves the device.
  final String body;

  @override
  String toString() => 'ClaveApiException($statusCode): $body';
}

/// {@template clave_network_exception}
/// Thrown when a Cl@ve request could not be completed at all — the host was
/// unreachable, the connection failed, or [ClaveHttpClient.timeout] elapsed.
///
/// Distinct from [ClaveApiException], which means the server answered and
/// said no.
/// {@endtemplate}
class ClaveNetworkException implements Exception {
  /// Creates a [ClaveNetworkException] describing the transport failure.
  const ClaveNetworkException(this.message);

  /// What went wrong at the transport level.
  final String message;

  @override
  String toString() => 'ClaveNetworkException: $message';
}
