import 'dart:convert';

import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

PersonalData person(String given, String surnames, String type) => PersonalData(
  fullName: '$given $surnames',
  givenName: given,
  surnames: surnames,
  nif: '12345678Z',
  country: 'ES',
  certificateType: type,
);

SignedData withCertificate(String certificate) => SignedData(
  signedData: utf8.encode('x'),
  signedDataBase64: 'eA==',
  certificate: certificate,
);

void main() {
  group('PersonalData', () {
    test('recognises the certificate with or without the accent', () {
      expect(
        person('J', 'G', 'AUTENTICACIÓN').certificateKind,
        DnieCertificateType.auth,
      );
      expect(person('J', 'G', 'AUTENTICACIÓN').isAuthCert, isTrue);
      expect(person('J', 'G', 'FIRMA').isSigningCert, isTrue);
      expect(person('J', 'G', '').certificateKind, isNull);
    });

    test('displayName title-cases and keeps particles lower case', () {
      final data = person('MARIA', 'DE LA CRUZ GARCIA', 'FIRMA');
      expect(data.displayName, 'Maria de la Cruz Garcia');
      expect(data.initials, 'M.D.');
    });
  });

  test('DnieCertificateType.fromValue ignores case and rejects unknowns', () {
    expect(DnieCertificateType.fromValue(' auth '), DnieCertificateType.auth);
    expect(DnieCertificateType.fromValue('SIGN'), DnieCertificateType.sign);
    expect(DnieCertificateType.fromValue('other'), isNull);
  });

  test('certificateDer decodes Base64 and refuses anything else', () {
    expect(withCertificate('AQID').certificateDer, [1, 2, 3]);
    expect(withCertificate('not base64!').certificateDer, isNull);
    expect(withCertificate('').certificateDer, isNull);
  });
}
