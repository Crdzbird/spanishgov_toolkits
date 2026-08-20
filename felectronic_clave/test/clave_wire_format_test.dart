import 'dart:convert';

import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Every expectation here is taken from the reference client that runs against
/// the real Cl@ve service, not from reading the specification.
void main() {
  group('Cl@ve Movil notification API', () {
    test('the create body is a params envelope, not a flat object', () async {
      // The regression this guards: sending {"doc":...,"contraste":...} is a
      // body this endpoint does not accept, so Cl@ve Movil never worked.
      late http.Request seen;
      final client = ClaveHttpClient(
        MockClient((req) async {
          seen = req;
          return http.Response('{}', 200);
        }),
      );

      await client.createNotificationCode(
        url: 'https://x/claveMovil',
        clientId: 'c',
        document: '12345678Z',
        contrast: '01-01-2030',
      );

      expect(jsonDecode(seen.body), {
        'params': [
          {'key': 'doc', 'value': '12345678Z'},
          {'key': 'contraste', 'value': '01-01-2030'},
        ],
      });
    });

    test('credentials go in the headers on create', () async {
      late http.Request seen;
      final client = ClaveHttpClient(
        MockClient((req) async {
          seen = req;
          return http.Response('{}', 200);
        }),
      );

      await client.createNotificationCode(
        url: 'https://x/claveMovil',
        clientId: 'c',
        clientSecret: 's3cret',
        document: '12345678Z',
        contrast: '01-01-2030',
      );

      // The two Movil endpoints genuinely disagree: headers here, body on
      // validate. Neither is a mistake to be tidied.
      expect(seen.headers['client_id'], 'c');
      expect(seen.headers['client_secret'], 's3cret');
      expect(seen.body, isNot(contains('client_secret')));
    });

    test('the response envelope is read back the same way', () {
      const body = {
        'params': [
          {'key': 'token_clave_movil', 'value': 'tok'},
          {'key': 'cod_verificacion', 'value': '1234'},
        ],
      };
      String read(String key) => ClaveKeyValues.read(body, key);
      expect(read(ClaveKeyValues.mobileToken), 'tok');
      expect(read(ClaveKeyValues.verificationCode), '1234');
    });

    test('a flat response is tolerated too', () {
      expect(
        ClaveKeyValues.read(
          {'token_clave_movil': 'tok'},
          ClaveKeyValues.mobileToken,
        ),
        'tok',
      );
    });

    test('a missing key reads as empty rather than throwing', () {
      expect(ClaveKeyValues.read(const {}, ClaveKeyValues.mobileToken), '');
    });
  });

  group('logout', () {
    test('the access token authenticates the call as a bearer', () async {
      late http.Request seen;
      final client = ClaveHttpClient(
        MockClient((req) async {
          seen = req;
          return http.Response('', 204);
        }),
      );

      await client.logout(
        url: 'https://x/logout',
        clientId: 'c',
        clientSecret: 's',
        accessToken: 'at',
        refreshToken: 'rt',
      );

      expect(seen.headers['Authorization'], 'Bearer at');
      // The body names the session to end; an earlier revision sent the access
      // token as a `token` field with no header, which is a different request.
      expect(seen.body, contains('refresh_token=rt'));
      expect(seen.body, isNot(contains('token=at')));
    });
  });

  group('failure bodies', () {
    test('the notification API reports through messages[].details', () async {
      final client = ClaveHttpClient(
        MockClient(
          (_) async => http.Response(
            '{"messages":[{"alias":null,"message":null,"type":null,'
            '"details":"Error de validación en el Dato de Contraste. "}]}',
            400,
          ),
        ),
      );
      await expectLater(
        client.createNotificationCode(
          url: 'https://x/claveMovil',
          clientId: 'c',
          document: '12345678Z',
          contrast: 'wrong',
        ),
        throwsA(
          isA<ClaveApiException>().having(
            (e) => e.body,
            'body',
            'Error de validación en el Dato de Contraste. ',
          ),
        ),
      );
    });

    test('Keycloak reports through error_description', () async {
      // The validate endpoint is Keycloak and uses a different shape entirely.
      // An earlier revision read only the messages[] shape, so every failure
      // from validation arrived unparsed and could not be classified.
      final client = ClaveHttpClient(
        MockClient(
          (_) async => http.Response(
            '{"error":"invalid_grant","error_description":'
            '"La petición Clave Móvil ha expirado. "}',
            400,
          ),
        ),
      );
      await expectLater(
        client.validateNotificationCode(
          url: 'https://x/token',
          clientId: 'c',
          nif: '12345678Z',
          tokenClaveMovil: 'tok',
        ),
        throwsA(
          // The description alone, not the whole JSON envelope: this is the
          // text a caller may show, so leaving it wrapped in braces and field
          // names would be a worse message. Classification happens to survive
          // either way, since it substring-matches.
          isA<ClaveApiException>().having(
            (e) => e.body,
            'body',
            'La petición Clave Móvil ha expirado. ',
          ),
        ),
      );
    });
  });

  group('identity providers', () {
    test('STORK and eIDAS are distinct providers', () {
      // The gateway treats them as different IDPs and the reference offers
      // both; collapsing them would silently change which one a caller gets.
      expect(ClaveAuthMethod.stork.idpValue, 'STORK');
      expect(ClaveAuthMethod.europeanCredential.idpValue, 'EIDAS');
    });

    test('every idp value matches the reference client', () {
      expect(
        {
          for (final m in ClaveAuthMethod.values) m.name: m.idpValue,
        },
        {
          'clavePin': 'PIN24H',
          'clavePermanente': 'SEGSOC',
          'electronicCertificate': 'AFIRMA',
          'stork': 'STORK',
          'europeanCredential': 'EIDAS',
          'claveMovil': 'CLVMOVIL',
        },
      );
    });
  });
}
