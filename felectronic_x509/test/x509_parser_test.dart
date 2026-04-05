import 'dart:convert';
import 'dart:typed_data';

import 'package:felectronic_x509/felectronic_x509.dart';
import 'package:test/test.dart';

// A self-signed RSA 2048-bit test certificate generated with openssl.
const _testCertBase64 =
    'MIIEATCCAumgAwIBAgIUTaH9ykMiIPKOu41d50TC7J5pJgUwDQYJKoZIhvcNAQEL'
    'BQAwYzELMAkGA1UEBhMCRVMxETAPBgNVBAoMCFRlc3QgT3JnMRIwEAYDVQQLDAlU'
    'ZXN0IFVuaXQxGTAXBgNVBAMMEFRlc3QgQ2VydGlmaWNhdGUxEjAQBgNVBAUTCTEy'
    'MzQ1Njc4QTAeFw0yNjAzMjkyMDM1MThaFw0zNjAzMjYyMDM1MThaMGMxCzAJBgNV'
    'BAYTAkVTMREwDwYDVQQKDAhUZXN0IE9yZzESMBAGA1UECwwJVGVzdCBVbml0MRkw'
    'FwYDVQQDDBBUZXN0IENlcnRpZmljYXRlMRIwEAYDVQQFEwkxMjM0NTY3OEEwggEi'
    'MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDxHW9AAsnWnztI6LJyq59o55Xe'
    'aYYtsrG6j3+uYBp7Q/fHYxigc5jax1qmORXywRFuFvW4sbR1Q1i59gNxfSWbp57r'
    'vA0lM4lc3aPSIYWlX4y1pPPGVGxf2OUefhl/VSt1OWGVlqxltIuk6nz4YJ+Jf9Jq'
    'ZD/oYthk+j0Lo3xEpVAgXAhD6Lz9c9e2fiULWKJ6aahnfniHgj4PhpI20pbfR4BL'
    'PrIyw5hVjsVUzAWD+21uf4KvxtJvLTOs96n2lUhM4sfaM45RhSUdXhiTHUTXHCHF'
    'jSvilpz/xL8R3aSFn8Yf1m5g4eunmIcWdH66/LV4DuP1wDagXZvj227R691zAgMB'
    'AAGjgawwgakwHQYDVR0OBBYEFDKKagyjqpVY2Nk92IGINChrsL2jMB8GA1UdIwQY'
    'MBaAFDKKagyjqpVY2Nk92IGINChrsL2jMC0GA1UdEQQmMCSCEHRlc3QuZXhhbXBs'
    'ZS5jb22BEHRlc3RAZXhhbXBsZS5jb20wDgYDVR0PAQH/BAQDAgXgMB0GA1UdJQQW'
    'MBQGCCsGAQUFBwMCBggrBgEFBQcDBDAJBgNVHRMEAjAAMA0GCSqGSIb3DQEBCwUA'
    'A4IBAQC+Govyt6bYFiNrUC+dSlDlrdJQ5zuL6IUArcAPcGW5eZZS3uqvG/uatpKj'
    'UG27HVRB/vTEdngfKkrjL7WT4BqXxgDQwo0gYdFpPrt1lJrioSwsuIkuJO5OcfdN'
    'rgcfPdSY4wq1cbDuPy41K7bt3hqAluLdbeVmExTlq6ebVtWSoP/ZYCbTYCDXsZTQ'
    'FGVsQPX9+WGSOOsfJrypusp4tknoEEQS6odh03qQgmrSJzDFjWWk7E3LrH+ZLMHX'
    '/rOBecXwSt9jWJVkM8aLZ/OAD06oMLa78FxYXLGSzfm7fxH3ZC0axuNwjceto1L3'
    'csrRhTFOjBDGJZWm8/XhdKucSU6M';

void main() {
  late X509Certificate cert;

  setUpAll(() {
    cert = X509Parser.fromBase64(_testCertBase64);
  });

  group('X509Parser', () {
    test('parses certificate version (v3)', () {
      expect(cert.version, 3);
    });

    test('parses serial number', () {
      expect(cert.serialNumber, isNotEmpty);
      // Serial number should be hex.
      expect(
        cert.serialNumber,
        matches(RegExp(r'^[0-9A-F]+$')),
      );
    });

    test('parses signature algorithm', () {
      expect(cert.signatureAlgorithm, '1.2.840.113549.1.1.11');
      expect(cert.signatureAlgorithmName, 'SHA256withRSA');
    });

    test('parses issuer distinguished name', () {
      expect(cert.issuer.country, 'ES');
      expect(cert.issuer.organization, 'Test Org');
      expect(cert.issuer.organizationalUnit, 'Test Unit');
      expect(cert.issuer.commonName, 'Test Certificate');
      expect(cert.issuer.serialNumber, '12345678A');
    });

    test('parses subject distinguished name', () {
      expect(cert.subject.country, 'ES');
      expect(cert.subject.organization, 'Test Org');
      expect(cert.subject.organizationalUnit, 'Test Unit');
      expect(cert.subject.commonName, 'Test Certificate');
      expect(cert.subject.serialNumber, '12345678A');
    });

    test('parses validity dates', () {
      expect(cert.notValidBefore, DateTime.utc(2026, 3, 29, 20, 35, 18));
      expect(cert.notValidAfter, DateTime.utc(2036, 3, 26, 20, 35, 18));
    });

    test('parses public key algorithm', () {
      expect(cert.publicKeyAlgorithm, 'RSA');
    });

    test('parses public key size', () {
      expect(cert.publicKeySize, 2048);
    });

    test('parses public key bytes', () {
      expect(cert.publicKeyBytes, isNotEmpty);
    });

    test('parses key usage extension (critical)', () {
      final ku = cert.keyUsage;
      expect(ku, contains('digitalSignature'));
      expect(ku, contains('nonRepudiation'));
      expect(ku, contains('keyEncipherment'));
    });

    test('parses extended key usage extension', () {
      final eku = cert.extendedKeyUsage;
      expect(eku, contains('clientAuth'));
      expect(eku, contains('emailProtection'));
    });

    test('parses subject alternative names', () {
      final san = cert.subjectAltNames;
      expect(san, contains('test.example.com'));
      expect(san, contains('test@example.com'));
    });

    test('parses basic constraints (not CA)', () {
      expect(cert.isCA, isFalse);
    });

    test('detects self-signed certificate', () {
      expect(cert.isSelfSigned, isTrue);
    });

    test('isCurrentlyValid returns true for valid cert', () {
      // This cert is valid from 2026 to 2036.
      // The test runs in 2026 so it should be valid.
      expect(cert.isCurrentlyValid, isTrue);
    });

    test('isExpired returns false for valid cert', () {
      expect(cert.isExpired, isFalse);
    });

    test('daysUntilExpiry is positive', () {
      expect(cert.daysUntilExpiry, greaterThan(0));
    });

    test('subject key identifier is present', () {
      expect(cert.subjectKeyIdentifier, isNotNull);
      expect(cert.subjectKeyIdentifier, isNotEmpty);
    });

    test('authority key identifier is present', () {
      expect(cert.authorityKeyIdentifier, isNotNull);
    });

    test('signature bytes are not empty', () {
      expect(cert.signatureBytes, isNotEmpty);
    });

    test('TBS certificate bytes are not empty', () {
      expect(cert.tbsCertificateBytes, isNotEmpty);
    });

    test('DER encoded bytes are available', () {
      expect(cert.derEncoded, isNotEmpty);
      expect(
        cert.derEncoded,
        equals(base64.decode(_testCertBase64)),
      );
    });

    test('PEM encoding round-trips correctly', () {
      final pem = cert.pem;
      expect(pem, startsWith('-----BEGIN CERTIFICATE-----'));
      expect(pem, endsWith('-----END CERTIFICATE-----'));

      // Re-parse from PEM.
      final reparsed = X509Parser.fromPem(pem);
      expect(reparsed.subject.commonName, cert.subject.commonName);
      expect(reparsed.serialNumber, cert.serialNumber);
      expect(reparsed.signatureAlgorithm, cert.signatureAlgorithm);
    });

    test('fromBase64 works', () {
      final parsed = X509Parser.fromBase64(_testCertBase64);
      expect(parsed.subject.commonName, 'Test Certificate');
    });

    test('fromDer works', () {
      final bytes = base64.decode(_testCertBase64);
      final parsed = X509Parser.fromDer(Uint8List.fromList(bytes));
      expect(parsed.subject.commonName, 'Test Certificate');
    });

    test('throws FormatException on invalid DER', () {
      expect(
        () => X509Parser.fromDer(Uint8List.fromList([0, 1, 2])),
        throwsFormatException,
      );
    });

    test('throws FormatException on empty bytes', () {
      expect(
        () => X509Parser.fromDer(Uint8List(0)),
        throwsFormatException,
      );
    });

    test('throws FormatException on truncated certificate', () {
      final bytes = base64.decode(_testCertBase64);
      final truncated = Uint8List.sublistView(bytes, 0, 50);
      expect(
        () => X509Parser.fromDer(truncated),
        throwsFormatException,
      );
    });

    test('throws FormatException on invalid PEM', () {
      expect(
        () => X509Parser.fromPem('not a pem'),
        throwsFormatException,
      );
    });

    test('throws FormatException on empty PEM', () {
      expect(
        () => X509Parser.fromPem(
          '-----BEGIN CERTIFICATE----------END CERTIFICATE-----',
        ),
        throwsFormatException,
      );
    });

    test('throws FormatException on invalid base64', () {
      expect(
        () => X509Parser.fromBase64('!!!invalid!!!'),
        throwsFormatException,
      );
    });
  });
}
