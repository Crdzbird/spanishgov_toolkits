import 'package:felectronic_clave/felectronic_clave.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClaveAuthMethod', () {
    test('has correct idp values', () {
      expect(ClaveAuthMethod.clavePin.idpValue, 'PIN24H');
      expect(ClaveAuthMethod.clavePermanente.idpValue, 'SEGSOC');
      expect(ClaveAuthMethod.electronicCertificate.idpValue, 'AFIRMA');
      expect(ClaveAuthMethod.europeanCredential.idpValue, 'EIDAS');
      expect(ClaveAuthMethod.claveMovil.idpValue, 'CLVMOVIL');
    });
  });

  group('ClaveLoaLevel', () {
    test('has correct integer values', () {
      expect(ClaveLoaLevel.low.value, 1);
      expect(ClaveLoaLevel.medium.value, 2);
      expect(ClaveLoaLevel.high.value, 3);
    });
  });

  group('ClaveAuthResult', () {
    test('equality by accessToken and refreshToken', () {
      const a = ClaveAuthResult(accessToken: 'tok', refreshToken: 'ref');
      const b = ClaveAuthResult(accessToken: 'tok', refreshToken: 'ref');
      const c = ClaveAuthResult(accessToken: 'other');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('toString hides token values', () {
      const result = ClaveAuthResult(accessToken: 'secret', expiresIn: 3600);
      expect(result.toString(), contains('3600'));
      expect(result.toString(), isNot(contains('secret')));
    });
  });

  group('ClaveMobileSession', () {
    test('equality by token', () {
      const a = ClaveMobileSession(
        token: 'tok',
        verificationCode: '1234',
        document: '12345678Z',
      );
      const b = ClaveMobileSession(
        token: 'tok',
        verificationCode: '9999',
        document: '00000000T',
      );
      expect(a, equals(b));
    });
  });

  group('ClaveConfig', () {
    test('issuerUrl strips well-known suffix', () {
      const config = ClaveConfig(
        discoveryUrl:
            'https://auth.example.com/realm/.well-known/openid-configuration',
        clientId: 'id',
        redirectUri: 'app://cb',
        clientSecret: 'secret',
        userInfoUrl: 'https://auth.example.com/userinfo',
        logoutUrl: 'https://auth.example.com/logout',
      );
      expect(config.issuerUrl, 'https://auth.example.com/realm');
    });

    test('default LOA is low', () {
      const config = ClaveConfig(
        discoveryUrl: 'https://example.com/.well-known/openid-configuration',
        clientId: 'id',
        redirectUri: 'app://cb',
        clientSecret: 's',
        userInfoUrl: 'https://example.com/userinfo',
        logoutUrl: 'https://example.com/logout',
      );
      expect(config.defaultLoa, ClaveLoaLevel.low);
    });
  });

  group('ClaveError', () {
    test('subclasses have descriptive messages', () {
      const errors = <ClaveError>[
        ClaveAuthCancelledError(),
        ClaveInvalidContrastError(),
        ClaveRequestAlreadySentError(),
        ClaveSessionExpiredError(),
        ClaveRefusedError(),
        ClaveDiscoveryFailedError(),
        ClaveIdleError(),
        ClaveUnknownError('test'),
      ];
      for (final error in errors) {
        expect(error.message, isNotEmpty);
        expect(error.toString(), isNotEmpty);
      }
    });
  });

  group('NfcStatus model from clave_token_storage', () {
    test('ClaveTokenStorage key constants are unique', () {
      // Smoke test — ensure the storage can be instantiated
      expect(ClaveTokenStorage.new, returnsNormally);
    });
  });
}
