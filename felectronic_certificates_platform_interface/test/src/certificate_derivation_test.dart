import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';
import 'package:felectronic_certificates_platform_interface/src/method_channel_felectronic_certificates.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/certificate_fixtures.dart';

/// Tests the DER-derivation path: the platform message carries only the
/// serial and the alias, and every other field is decoded from `encoded` by
/// `felectronic_x509`.
///
/// Each case runs against a real certificate, and the message never carries a
/// name, date or usage string — so a passing assertion can only mean the
/// value came out of the DER.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelFelectronicCertificates platform;
  late _StubHostApi api;

  setUp(() {
    platform = MethodChannelFelectronicCertificates();
    api = _StubHostApi();
    platform.api = api;
  });

  /// Builds a message the way both platforms now do: the keystore supplies
  /// the serial, the optional alias, and the DER. Nothing else.
  DeviceCertificateMessage nativeMessage(
    Uint8List der, {
    String serialNumber = 'b5a1c3',
    String? alias,
  }) => DeviceCertificateMessage(
    serialNumber: serialNumber,
    alias: alias,
    encoded: der,
  );

  Future<DeviceCertificate> derive(DeviceCertificateMessage message) async {
    api.allCertificatesResult = [message];
    final result = await platform.getAllCertificates();
    return result.single;
  }

  group('field derivation from DER', () {
    test('subject CN is decoded, commas preserved', () async {
      final cert = await derive(nativeMessage(signingCertDer));

      expect(cert.holderName, 'GARCIA GARCIA, JUAN - 12345678Z');
    });

    test('issuer CN is decoded', () async {
      final cert = await derive(nativeMessage(signingCertDer));

      expect(cert.issuerName, fixtureIssuerCommonName);
      expect(cert.issuerName, isNot(cert.holderName));
    });

    test('expiry is an exact UTC instant', () async {
      final cert = await derive(nativeMessage(signingCertDer));

      expect(cert.expirationDate, DateTime.utc(2028));
      expect(cert.expirationDate!.isUtc, isTrue);
      expect(cert.hasKnownExpiry, isTrue);
    });

    test('serial number passes through as the keystore key', () async {
      final cert = await derive(nativeMessage(signingCertDer));

      // Not re-derived from the DER: felectronic_x509 would render this
      // certificate's own serial in a different spelling, and the keystore
      // only answers to its own.
      expect(cert.serialNumber, 'b5a1c3');
    });

    test('alias is preserved from keystore attributes', () async {
      final cert = await derive(
        nativeMessage(signingCertDer, alias: 'Mi certificado'),
      );

      expect(cert.alias, 'Mi certificado');
      expect(cert.displayName, 'Mi certificado');
    });

    test('GeneralizedTime notAfter (>= 2050) decodes correctly', () async {
      // notBefore is UTCTime and notAfter is GeneralizedTime in this
      // certificate — RFC 5280 4.1.2.5 requires the switch at 2050.
      final cert = await derive(nativeMessage(generalizedTimeCertDer));

      expect(cert.expirationDate, DateTime.utc(2060));
      expect(cert.isExpired, isFalse);
    });

    test('expired certificate is reported as expired', () async {
      final cert = await derive(nativeMessage(expiredCertDer));

      expect(cert.expirationDate, DateTime.utc(2021));
      expect(cert.isExpired, isTrue);
      expect(cert.daysUntilExpiry, isNegative);
      expect(cert.expiryStatus, 'Expired');
    });
  });

  group('key usage mapping', () {
    test('nonRepudiation maps to signing, and only signing', () async {
      final cert = await derive(nativeMessage(signingCertDer));

      expect(cert.usages, [CertKeyUsage.signing]);
      expect(cert.canSign, isTrue);
      expect(cert.canAuthenticate, isFalse);
      expect(cert.canEncrypt, isFalse);
    });

    test('digitalSignature maps to authentication, not signing', () async {
      final cert = await derive(nativeMessage(authCertDer));

      expect(cert.usages, [CertKeyUsage.authentication]);
      expect(cert.canAuthenticate, isTrue);
      expect(cert.canSign, isFalse);
    });

    test(
      'keyEncipherment + dataEncipherment collapse to one encryption',
      () async {
        final cert = await derive(nativeMessage(encryptionCertDer));

        expect(cert.usages, [CertKeyUsage.encryption]);
        expect(cert.canEncrypt, isTrue);
      },
    );

    test('both signing bits produce both usages in bit order', () async {
      final cert = await derive(nativeMessage(expiredCertDer));

      expect(cert.usages, [CertKeyUsage.authentication, CertKeyUsage.signing]);
    });

    test(
      'absent keyUsage extension does not fabricate signing capability',
      () async {
        // Both native layers previously answered SIGNING + AUTHENTICATION here,
        // asserting capabilities the certificate never claimed.
        final cert = await derive(nativeMessage(noKeyUsageCertDer));

        expect(cert.usages, isEmpty);
        expect(cert.canSign, isFalse);
      },
    );
  });

  group('undecodable certificates', () {
    test('malformed DER yields empty fields and an unknown expiry', () async {
      final cert = await derive(
        DeviceCertificateMessage(
          serialNumber: 'abc123',
          encoded: Uint8List.fromList([1, 2, 3]),
        ),
      );

      expect(cert.serialNumber, 'abc123');
      expect(cert.holderName, isEmpty);
      expect(cert.issuerName, isEmpty);
      expect(cert.usages, isEmpty);
      // Crucially null, not the epoch: unknown is not the same as expired.
      expect(cert.expirationDate, isNull);
      expect(cert.hasKnownExpiry, isFalse);
      expect(cert.isExpired, isFalse);
      expect(cert.daysUntilExpiry, isNull);
      expect(cert.expiryStatus, 'Expiry unknown');
      expect(cert.isExpiringSoon, isFalse);
    });

    test('empty DER does not throw', () async {
      final cert = await derive(
        DeviceCertificateMessage(
          serialNumber: 'abc123',
          encoded: Uint8List(0),
        ),
      );

      expect(cert.holderName, isEmpty);
      expect(cert.expirationDate, isNull);
    });

    test('one malformed certificate does not fail the whole list', () async {
      api.allCertificatesResult = [
        nativeMessage(signingCertDer, serialNumber: 'good'),
        DeviceCertificateMessage(
          serialNumber: 'bad',
          encoded: Uint8List.fromList([0x30, 0x82, 0xFF, 0xFF]),
        ),
      ];

      final result = await platform.getAllCertificates();

      expect(result, hasLength(2));
      expect(result[0].holderName, 'GARCIA GARCIA, JUAN - 12345678Z');
      expect(result[1].holderName, isEmpty);
    });
  });

  group('serial canonicalization at the boundary', () {
    test('setDefaultCertificateBySerialNumber canonicalizes', () async {
      // The iOS spelling of 0xB5A1C3, carrying the DER sign-pad byte.
      await platform.setDefaultCertificateBySerialNumber('00B5A1C3');

      expect(api.lastSetSerial, 'b5a1c3');
    });

    test('deleteCertificateBySerialNumber canonicalizes', () async {
      await platform.deleteCertificateBySerialNumber('00:B5:A1:C3');

      expect(api.lastDeleteSerial, 'b5a1c3');
    });
  });

  group('CertSignAlgorithm.wire', () {
    test('maps every algorithm to its wire enum', () {
      expect(
        CertSignAlgorithm.values.map((a) => a.wire).toList(),
        [
          CertSignAlgorithmMessage.sha256rsa,
          CertSignAlgorithmMessage.sha384rsa,
          CertSignAlgorithmMessage.sha512rsa,
          CertSignAlgorithmMessage.sha256ec,
          CertSignAlgorithmMessage.sha384ec,
          CertSignAlgorithmMessage.sha512ec,
        ],
      );
    });

    test('signing sends the typed enum, not a string', () async {
      await platform.signWithDefaultCertificate(
        Uint8List.fromList([1, 2, 3]),
        algorithm: CertSignAlgorithm.sha512ec,
      );

      expect(api.lastSignAlgorithm, CertSignAlgorithmMessage.sha512ec);
    });
  });

  group('CertKeyUsage.fromX509Flags', () {
    test('maps the modelled flags', () {
      expect(
        CertKeyUsage.fromX509Flags(['digitalSignature']),
        [CertKeyUsage.authentication],
      );
      expect(
        CertKeyUsage.fromX509Flags(['nonRepudiation']),
        [CertKeyUsage.signing],
      );
      expect(
        CertKeyUsage.fromX509Flags(['keyEncipherment']),
        [CertKeyUsage.encryption],
      );
      expect(
        CertKeyUsage.fromX509Flags(['dataEncipherment']),
        [CertKeyUsage.encryption],
      );
    });

    test('ignores flags outside the model', () {
      expect(
        CertKeyUsage.fromX509Flags([
          'keyAgreement',
          'keyCertSign',
          'cRLSign',
          'encipherOnly',
          'decipherOnly',
        ]),
        isEmpty,
      );
    });

    test('collapses duplicates, preserving first-seen order', () {
      expect(
        CertKeyUsage.fromX509Flags([
          'keyEncipherment',
          'dataEncipherment',
          'nonRepudiation',
          'nonRepudiation',
        ]),
        [CertKeyUsage.encryption, CertKeyUsage.signing],
      );
    });

    test('empty input yields empty output', () {
      expect(CertKeyUsage.fromX509Flags([]), isEmpty);
    });
  });
}

/// Stub host API capturing what crosses the boundary.
class _StubHostApi implements FelectronicCertificatesHostApi {
  List<DeviceCertificateMessage?>? allCertificatesResult;
  String? lastSetSerial;
  String? lastDeleteSerial;
  CertSignAlgorithmMessage? lastSignAlgorithm;

  @override
  // ignore: non_constant_identifier_names, Pigeon-generated field name.
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  // ignore: non_constant_identifier_names, Pigeon-generated field name.
  String get pigeonVar_messageChannelSuffix => '';

  @override
  Future<List<DeviceCertificateMessage?>> getAllCertificates() async =>
      allCertificatesResult ?? [];

  @override
  Future<DeviceCertificateMessage?> getDefaultCertificate() async =>
      throw UnimplementedError();

  @override
  Future<DeviceCertificateMessage?> selectDefaultCertificate() async =>
      throw UnimplementedError();

  @override
  Future<void> setDefaultCertificateBySerialNumber(String serialNumber) async {
    lastSetSerial = serialNumber;
  }

  @override
  Future<void> clearDefaultCertificate() async => throw UnimplementedError();

  @override
  Future<Uint8List> signWithDefaultCertificate(
    Uint8List data,
    CertSignAlgorithmMessage algorithm,
  ) async {
    lastSignAlgorithm = algorithm;
    return Uint8List.fromList([9, 9]);
  }

  @override
  Future<void> importCertificate(
    Uint8List pkcs12Data,
    String? password,
    String? alias,
  ) async => throw UnimplementedError();

  @override
  Future<void> deleteDefaultCertificate() async => throw UnimplementedError();

  @override
  Future<void> deleteCertificateBySerialNumber(String serialNumber) async {
    lastDeleteSerial = serialNumber;
  }
}
