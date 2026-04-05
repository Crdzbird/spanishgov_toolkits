import 'dart:convert';

/// Lightweight JWT payload parser.
///
/// Decodes the payload segment of a JWT token without
/// performing signature verification. Use only for extracting
/// claims from tokens already validated by the server.
abstract final class JwtParser {
  /// Decodes the payload of a JWT [token] and returns it as a map.
  ///
  /// Returns `null` if the token format is invalid.
  static Map<String, dynamic>? parsePayload(String? token) {
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  /// Extracts the NIF (preferred_username) from a JWT [token].
  ///
  /// Returns an empty string if the claim is not present.
  static String getNif(String token) {
    final payload = parsePayload(token);
    return (payload?['preferred_username'] as String?) ?? '';
  }
}
