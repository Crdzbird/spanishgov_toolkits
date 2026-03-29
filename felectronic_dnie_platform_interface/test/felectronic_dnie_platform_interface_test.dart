import 'dart:typed_data';

import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class FelectronicDnieMock extends FelectronicDniePlatform {
  static final mockResult = SignedData(
    signedData: Uint8List.fromList([1, 2, 3]),
    signedDataBase64: 'AQID',
    certificate: 'mockCert',
  );

  @override
  Future<SignedData> sign({
    required Uint8List data,
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) async =>
      mockResult;

  @override
  Future<void> stopSign() async {}

  @override
  Future<SignedData> readCertificate({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) async =>
      mockResult;

  @override
  Future<CardProbeResult> probeCard({int timeout = 30}) async =>
      const CardProbeResult(
        isValidDnie: true,
        atrHex: 'E1F35E11',
        tagId: 'ABCD',
      );

  @override
  Future<CertificateInfo> readCertificateDetails({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) async =>
      CertificateInfo(
        subjectCommonName: 'CN',
        subjectSerialNumber: '12345678Z',
        issuerCommonName: 'Issuer',
        issuerOrganization: 'Org',
        notValidBefore: DateTime(2021),
        notValidAfter: DateTime(2030),
        serialNumber: 'abc',
        isCurrentlyValid: true,
      );

  @override
  Future<PersonalData> readPersonalData({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) async =>
      const PersonalData(
        fullName: 'JUAN GARCIA',
        givenName: 'JUAN',
        surnames: 'GARCIA',
        nif: '12345678Z',
        country: 'ES',
        certificateType: 'FIRMA',
      );

  @override
  Future<void> verifyPin({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) async {}

  @override
  Future<NfcStatus> checkNfcAvailability() async =>
      const NfcStatus(isAvailable: true, isEnabled: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FelectronicDniePlatformInterface', () {
    late FelectronicDniePlatform platform;

    setUp(() {
      platform = FelectronicDnieMock();
      FelectronicDniePlatform.instance = platform;
    });

    group('sign', () {
      test('returns SignedData', () async {
        final result = await FelectronicDniePlatform.instance.sign(
          data: Uint8List(1),
          can: '123456',
          pin: 'password',
        );
        expect(result.signedDataBase64, 'AQID');
        expect(result.certificate, 'mockCert');
      });

      test('accepts auth certificate type', () async {
        final result = await FelectronicDniePlatform.instance.sign(
          data: Uint8List(1),
          can: '123456',
          pin: 'password',
          certificateType: DnieCertificateType.auth,
        );
        expect(result.signedDataBase64, 'AQID');
      });
    });

    group('stopSign', () {
      test('completes without error', () async {
        await expectLater(
          FelectronicDniePlatform.instance.stopSign(),
          completes,
        );
      });
    });

    group('readCertificate', () {
      test('returns SignedData', () async {
        final result =
            await FelectronicDniePlatform.instance.readCertificate(
          can: '654321',
          pin: 'myPin',
        );
        expect(result.certificate, 'mockCert');
      });

      test('accepts auth certificate type', () async {
        final result =
            await FelectronicDniePlatform.instance.readCertificate(
          can: '654321',
          pin: 'myPin',
          certificateType: DnieCertificateType.auth,
        );
        expect(result.certificate, 'mockCert');
      });
    });

    group('checkNfcAvailability', () {
      test('returns NfcStatus', () async {
        final result =
            await FelectronicDniePlatform.instance.checkNfcAvailability();
        expect(result.isAvailable, isTrue);
        expect(result.isEnabled, isTrue);
      });
    });
  });
}
