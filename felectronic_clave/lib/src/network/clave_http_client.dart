import 'dart:convert';

import 'package:http/http.dart' as http;

/// HTTP client for Cl@ve Movil API calls.
///
/// Provides typed methods for the notification code creation
/// and validation endpoints.
class ClaveHttpClient {
  /// Creates a client with an optional custom [http.Client].
  ClaveHttpClient([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  /// Creates a Cl@ve Movil notification code.
  ///
  /// Returns the raw JSON response body as a map.
  Future<Map<String, dynamic>> createNotificationCode({
    required String url,
    required String clientId,
    required String clientSecret,
    required String document,
    required String contrast,
  }) async {
    final response = await _client.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'client_id': clientId,
        'client_secret': clientSecret,
      },
      body: jsonEncode({
        'doc': document,
        'contraste': contrast,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw _mapHttpError(response);
  }

  /// Validates a Cl@ve Movil notification code (polls for user approval).
  ///
  /// Returns the raw JSON response body as a map.
  Future<Map<String, dynamic>> validateNotificationCode({
    required String url,
    required String clientId,
    required String clientSecret,
    required String nif,
    required String tokenClaveMovil,
  }) async {
    final response = await _client.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'password',
        'nif': nif,
        'token_clave_movil': tokenClaveMovil,
        'idp': 'AEAT',
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw _mapHttpError(response);
  }

  /// Validates a token against the userInfo endpoint.
  Future<Map<String, dynamic>> getUserInfo({
    required String url,
    required String accessToken,
  }) async {
    final response = await _client.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    return {};
  }

  /// Posts a logout request.
  Future<bool> logout({
    required String url,
    required String clientId,
    required String clientSecret,
    required String accessToken,
    required String refreshToken,
  }) async {
    final response = await _client.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'token': accessToken,
        'refresh_token': refreshToken,
      },
    );

    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Exception _mapHttpError(http.Response response) {
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

/// Exception thrown when a Cl@ve HTTP request returns a non-200 status code.
class ClaveApiException implements Exception {
  /// Creates a [ClaveApiException] with the given [statusCode] and [body].
  const ClaveApiException(this.statusCode, this.body);

  /// The HTTP status code of the response.
  final int statusCode;

  /// The raw response body.
  final String body;

  @override
  String toString() => 'ClaveApiException($statusCode): $body';
}
