import 'dart:async';

import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('status handling', () {
    test('any 2xx is a success, not only 200', () async {
      // A creation endpoint answering 201 was previously reported as an error.
      final client = ClaveHttpClient(
        MockClient(
          (_) async => http.Response('{"token_clave_movil":"t"}', 201),
        ),
      );
      final body = await client.createNotificationCode(
        url: 'https://x/create',
        clientId: 'c',
        document: '12345678Z',
        contrast: '01-01-2030',
      );
      expect(body['token_clave_movil'], 't');
    });

    test('a non-2xx carries the status through', () async {
      final client = ClaveHttpClient(
        MockClient((_) async => http.Response('nope', 409)),
      );
      await expectLater(
        client.createNotificationCode(
          url: 'https://x/create',
          clientId: 'c',
          document: '12345678Z',
          contrast: '01-01-2030',
        ),
        throwsA(
          isA<ClaveApiException>().having((e) => e.statusCode, 'status', 409),
        ),
      );
    });

    test('the detail message is lifted out of a Cl@ve error body', () async {
      final client = ClaveHttpClient(
        MockClient(
          (_) async => http.Response(
            '{"messages":[{"details":"Contraste no valido"}]}',
            400,
          ),
        ),
      );
      await expectLater(
        client.createNotificationCode(
          url: 'https://x/create',
          clientId: 'c',
          document: '12345678Z',
          contrast: 'bad',
        ),
        throwsA(
          isA<ClaveApiException>()
              .having((e) => e.body, 'body', 'Contraste no valido'),
        ),
      );
    });

    test('userInfo distinguishes a rejected token from an outage', () async {
      // Both used to come back as an empty map, and the caller logged the user
      // out for either.
      for (final status in [401, 503]) {
        final client = ClaveHttpClient(
          MockClient((_) async => http.Response('', status)),
        );
        await expectLater(
          client.getUserInfo(url: 'https://x/ui', accessToken: 'at'),
          throwsA(
            isA<ClaveApiException>()
                .having((e) => e.statusCode, 'status', status),
          ),
        );
      }
    });
  });

  group('transport failures', () {
    test('a stalled request is abandoned at the timeout', () async {
      final client = ClaveHttpClient(
        MockClient((_) => Completer<http.Response>().future), // never completes
        const Duration(milliseconds: 50),
      );
      await expectLater(
        client.getUserInfo(url: 'https://x/ui', accessToken: 'at'),
        throwsA(isA<ClaveNetworkException>()),
      );
    });

    test('a transport error is not mistaken for a rejection', () async {
      final client = ClaveHttpClient(
        MockClient((_) async => throw http.ClientException('no route')),
      );
      await expectLater(
        client.getUserInfo(url: 'https://x/ui', accessToken: 'at'),
        throwsA(isA<ClaveNetworkException>()),
      );
    });
  });

  group('request shape', () {
    test('a public client sends no client_secret', () async {
      late http.Request seen;
      final client = ClaveHttpClient(
        MockClient((req) async {
          seen = req;
          return http.Response('{}', 200);
        }),
      );
      await client.validateNotificationCode(
        url: 'https://x/validate',
        clientId: 'c',
        nif: '12345678Z',
        tokenClaveMovil: 'tok',
      );
      expect(seen.body, isNot(contains('client_secret')));
      expect(seen.body, contains('grant_type=password'));
    });

    test('a confidential client sends the secret it was given', () async {
      late http.Request seen;
      final client = ClaveHttpClient(
        MockClient((req) async {
          seen = req;
          return http.Response('{}', 200);
        }),
      );
      await client.validateNotificationCode(
        url: 'https://x/validate',
        clientId: 'c',
        clientSecret: 's3cret',
        nif: '12345678Z',
        tokenClaveMovil: 'tok',
      );
      expect(seen.body, contains('client_secret=s3cret'));
    });

    test('logout reports whether the server accepted it', () async {
      final ok = ClaveHttpClient(
        MockClient((_) async => http.Response('', 204)),
      );
      expect(
        await ok.logout(
          url: 'https://x/logout',
          clientId: 'c',
          accessToken: 'at',
          refreshToken: 'rt',
        ),
        isTrue,
      );
    });
  });
}
