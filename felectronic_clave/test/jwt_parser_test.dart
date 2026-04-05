import 'dart:convert';

import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JwtParser', () {
    // Build a fake JWT with given payload
    String buildJwt(Map<String, dynamic> payload) {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
      final signature = base64Url.encode(utf8.encode('fake-signature'));
      return '$header.$body.$signature';
    }

    group('parsePayload', () {
      test('parses valid JWT payload', () {
        final token = buildJwt({'sub': '123', 'name': 'Test'});
        final payload = JwtParser.parsePayload(token);
        expect(payload, isNotNull);
        expect(payload!['sub'], '123');
        expect(payload['name'], 'Test');
      });

      test('returns null for null input', () {
        expect(JwtParser.parsePayload(null), isNull);
      });

      test('returns null for invalid format', () {
        expect(JwtParser.parsePayload('not-a-jwt'), isNull);
        expect(JwtParser.parsePayload('a.b'), isNull);
      });
    });

    group('getNif', () {
      test('extracts preferred_username', () {
        final token = buildJwt({'preferred_username': '12345678Z'});
        expect(JwtParser.getNif(token), '12345678Z');
      });

      test('returns empty string when claim missing', () {
        final token = buildJwt({'sub': '123'});
        expect(JwtParser.getNif(token), '');
      });
    });
  });
}
