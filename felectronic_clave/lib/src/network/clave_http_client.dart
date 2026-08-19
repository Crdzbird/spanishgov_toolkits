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
        {'doc': document, 'contraste': contrast},
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
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          if (clientSecret != null) 'client_secret': clientSecret,
          'token': accessToken,
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

  ClaveApiException _mapHttpError(http.Response response) {
    final body = response.body;
    try {
      final json = jsonDecode(body);
      final messages = json is Map ? json['messages'] : null;
      if (messages is List && messages.isNotEmpty) {
        final first = messages.first;
        final details = first is Map ? first['details'] as String? : null;
        if (details != null) {
          return ClaveApiException(response.statusCode, details);
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
