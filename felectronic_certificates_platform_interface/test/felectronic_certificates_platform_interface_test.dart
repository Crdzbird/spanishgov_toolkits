import 'dart:typed_data';

import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class FelectronicCertificatesMock extends FelectronicCertificatesPlatform {
  static final mockCertificate = DeviceCertificate(
    serialNumber: 'abc123',
    holderName: 'GARCIA, JUAN',
    issuerName: 'FNMT',
    expirationDate: DateTime(2030),
    usages: const [CertKeyUsage.signing],
    encoded: Uint8List.fromList([1, 2, 3]),
  );

  @override
  Future<List<DeviceCertificate>> getAllCertificates() async =>
      [mockCertificate];

  @override
  Future<DeviceCertificate?> getDefaultCertificate() async => mockCertificate;

  @override
  Future<DeviceCertificate?> selectDefaultCertificate() async =>
      mockCertificate;

  @override
  Future<void> setDefaultCertificateBySerialNumber(
    String serialNumber,
  ) async {}

  @override
  Future<void> clearDefaultCertificate() async {}

  @override
  Future<Uint8List> signWithDefaultCertificate(
    Uint8List data, {
    CertSignAlgorithm algorithm = CertSignAlgorithm.sha256rsa,
  }) async =>
      Uint8List.fromList([10, 20]);

  @override
  Future<void> importCertificate(
    Uint8List pkcs12Data, {
    String? password,
    String? alias,
  }) async {}

  @override
  Future<void> deleteDefaultCertificate() async {}

  @override
  Future<void> deleteCertificateBySerialNumber(String serialNumber) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FelectronicCertificatesPlatformInterface', () {
    late FelectronicCertificatesPlatform platform;

    setUp(() {
      platform = FelectronicCertificatesMock();
      FelectronicCertificatesPlatform.instance = platform;
    });

    group('getAllCertificates', () {
      test('returns list of certificates', () async {
        final result =
            await FelectronicCertificatesPlatform.instance.getAllCertificates();
        expect(result, hasLength(1));
        expect(result.first.serialNumber, 'abc123');
      });
    });

    group('getDefaultCertificate', () {
      test('returns a certificate', () async {
        final result = await FelectronicCertificatesPlatform.instance
            .getDefaultCertificate();
        expect(result, isNotNull);
        expect(result!.holderName, 'GARCIA, JUAN');
      });
    });

    group('selectDefaultCertificate', () {
      test('returns a certificate', () async {
        final result = await FelectronicCertificatesPlatform.instance
            .selectDefaultCertificate();
        expect(result, isNotNull);
      });
    });

    group('signWithDefaultCertificate', () {
      test('returns signature bytes', () async {
        final result = await FelectronicCertificatesPlatform.instance
            .signWithDefaultCertificate(Uint8List.fromList([42]));
        expect(result, Uint8List.fromList([10, 20]));
      });
    });

    group('clearDefaultCertificate', () {
      test('completes without error', () async {
        await expectLater(
          FelectronicCertificatesPlatform.instance.clearDefaultCertificate(),
          completes,
        );
      });
    });

    group('importCertificate', () {
      test('completes without error', () async {
        await expectLater(
          FelectronicCertificatesPlatform.instance
              .importCertificate(Uint8List.fromList([1, 2, 3])),
          completes,
        );
      });
    });

    group('deleteDefaultCertificate', () {
      test('completes without error', () async {
        await expectLater(
          FelectronicCertificatesPlatform.instance.deleteDefaultCertificate(),
          completes,
        );
      });
    });

    group('deleteCertificateBySerialNumber', () {
      test('completes without error', () async {
        await expectLater(
          FelectronicCertificatesPlatform.instance
              .deleteCertificateBySerialNumber('abc123'),
          completes,
        );
      });
    });
  });
}
