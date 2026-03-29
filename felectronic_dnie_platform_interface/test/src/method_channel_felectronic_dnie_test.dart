import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:felectronic_dnie_platform_interface/src/method_channel_felectronic_dnie.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$MethodChannelFelectronicDnie', () {
    late MethodChannelFelectronicDnie platform;
    late _MockHostApi mockApi;

    setUp(() {
      platform = MethodChannelFelectronicDnie();
      mockApi = _MockHostApi();
      platform.api = mockApi;
    });

    test('sign passes correct arguments and returns SignedData', () async {
      mockApi.signResult = DnieSignedDataMessage(
        signedData: Uint8List.fromList([1, 2, 3]),
        signedDataBase64: 'AQID',
        certificate: 'certData',
      );

      final result = await platform.sign(
        data: Uint8List.fromList([42]),
        can: '123456',
        pin: 'myPin123',
      );

      expect(result.signedDataBase64, 'AQID');
      expect(result.certificate, 'certData');
      expect(mockApi.lastSignCan, '123456');
      expect(mockApi.lastSignPin, 'myPin123');
      expect(mockApi.lastSignCertificateType, 'SIGN');
    });

    test('sign passes AUTH certificate type', () async {
      mockApi.signResult = DnieSignedDataMessage(
        signedData: Uint8List.fromList([1, 2, 3]),
        signedDataBase64: 'AQID',
        certificate: 'certData',
      );

      await platform.sign(
        data: Uint8List.fromList([42]),
        can: '123456',
        pin: 'myPin123',
        certificateType: DnieCertificateType.auth,
      );

      expect(mockApi.lastSignCertificateType, 'AUTH');
    });

    test('sign throws DnieError on PlatformException', () async {
      mockApi.signError = PlatformException(
        code: 'DSDNIeWrongPINException',
        message: '2 retries left',
      );

      expect(
        () => platform.sign(
          data: Uint8List(1),
          can: '000000',
          pin: 'password',
        ),
        throwsA(isA<DnieWrongPinError>()),
      );
    });

    test('stopSign invokes correctly', () async {
      await platform.stopSign();
      expect(mockApi.stopSignCalled, isTrue);
    });

    test('readCertificate passes correct arguments', () async {
      mockApi.readCertificateResult = DnieSignedDataMessage(
        signedData: Uint8List(0),
        signedDataBase64: '',
        certificate: 'myCert',
      );

      final result = await platform.readCertificate(
        can: '654321',
        pin: 'myPin456',
        timeout: 15,
      );

      expect(result.certificate, 'myCert');
      expect(mockApi.lastReadCertCan, '654321');
      expect(mockApi.lastReadCertPin, 'myPin456');
      expect(mockApi.lastReadCertTimeout, 15);
      expect(mockApi.lastReadCertCertificateType, 'SIGN');
    });

    test('readCertificate passes AUTH certificate type', () async {
      mockApi.readCertificateResult = DnieSignedDataMessage(
        signedData: Uint8List(0),
        signedDataBase64: '',
        certificate: 'myCert',
      );

      await platform.readCertificate(
        can: '654321',
        pin: 'myPin456',
        certificateType: DnieCertificateType.auth,
      );

      expect(mockApi.lastReadCertCertificateType, 'AUTH');
    });

    test('probeCard returns CardProbeResult', () async {
      mockApi.probeCardResult = DnieCardProbeMessage(
        isValidDnie: true,
        atrHex: 'E1F35E11',
        tagId: 'ABCD1234',
      );

      final result = await platform.probeCard();
      expect(result.isValidDnie, isTrue);
      expect(result.atrHex, 'E1F35E11');
      expect(result.tagId, 'ABCD1234');
    });

    test('readCertificateDetails returns CertificateInfo', () async {
      mockApi.certDetailsResult = DnieCertificateDetailsMessage(
        subjectCommonName: 'GARCIA LOPEZ, JUAN (FIRMA)',
        subjectSerialNumber: '12345678Z',
        issuerCommonName: 'AC DNIE 001',
        issuerOrganization: 'FNMT-RCM',
        notValidBefore: 1609459200000,
        notValidAfter: 1893456000000,
        serialNumber: 'abc123',
        isCurrentlyValid: true,
      );

      final result = await platform.readCertificateDetails(
        can: '123456',
        pin: 'myPin',
      );

      expect(result.subjectCommonName, 'GARCIA LOPEZ, JUAN (FIRMA)');
      expect(result.subjectSerialNumber, '12345678Z');
      expect(result.isCurrentlyValid, isTrue);
      expect(mockApi.lastCertDetailsCertificateType, 'SIGN');
    });

    test('readCertificateDetails passes AUTH certificate type', () async {
      mockApi.certDetailsResult = DnieCertificateDetailsMessage(
        subjectCommonName: 'GARCIA LOPEZ, JUAN (AUTENTICACION)',
        subjectSerialNumber: '12345678Z',
        issuerCommonName: 'AC DNIE 001',
        issuerOrganization: 'FNMT-RCM',
        notValidBefore: 1609459200000,
        notValidAfter: 1893456000000,
        serialNumber: 'abc123',
        isCurrentlyValid: true,
      );

      await platform.readCertificateDetails(
        can: '123456',
        pin: 'myPin',
        certificateType: DnieCertificateType.auth,
      );

      expect(mockApi.lastCertDetailsCertificateType, 'AUTH');
    });

    test('readPersonalData returns PersonalData', () async {
      mockApi.personalDataResult = DniePersonalDataMessage(
        fullName: 'JUAN GARCIA LOPEZ',
        givenName: 'JUAN',
        surnames: 'GARCIA LOPEZ',
        nif: '12345678Z',
        country: 'ES',
        certificateType: 'FIRMA',
      );

      final result = await platform.readPersonalData(
        can: '123456',
        pin: 'myPin',
      );

      expect(result.fullName, 'JUAN GARCIA LOPEZ');
      expect(result.nif, '12345678Z');
      expect(result.certificateType, 'FIRMA');
      expect(mockApi.lastPersonalDataCertificateType, 'SIGN');
    });

    test('readPersonalData passes AUTH certificate type', () async {
      mockApi.personalDataResult = DniePersonalDataMessage(
        fullName: 'JUAN GARCIA LOPEZ',
        givenName: 'JUAN',
        surnames: 'GARCIA LOPEZ',
        nif: '12345678Z',
        country: 'ES',
        certificateType: 'AUTENTICACION',
      );

      await platform.readPersonalData(
        can: '123456',
        pin: 'myPin',
        certificateType: DnieCertificateType.auth,
      );

      expect(mockApi.lastPersonalDataCertificateType, 'AUTH');
    });

    test('verifyPin completes without error', () async {
      await platform.verifyPin(
        can: '123456',
        pin: 'myPin',
      );
      expect(mockApi.verifyPinCalled, isTrue);
      expect(mockApi.lastVerifyPinCertificateType, 'SIGN');
    });

    test('verifyPin passes AUTH certificate type', () async {
      await platform.verifyPin(
        can: '123456',
        pin: 'myPin',
        certificateType: DnieCertificateType.auth,
      );
      expect(mockApi.lastVerifyPinCertificateType, 'AUTH');
    });

    test('checkNfcAvailability returns NfcStatus', () async {
      mockApi.nfcStatusResult = DnieNfcStatusMessage(
        isAvailable: true,
        isEnabled: true,
      );

      final result = await platform.checkNfcAvailability();
      expect(result.isAvailable, isTrue);
      expect(result.isEnabled, isTrue);
    });

    test('checkNfcAvailability returns disabled NFC', () async {
      mockApi.nfcStatusResult = DnieNfcStatusMessage(
        isAvailable: true,
        isEnabled: false,
      );

      final result = await platform.checkNfcAvailability();
      expect(result.isAvailable, isTrue);
      expect(result.isEnabled, isFalse);
    });
  });
}

class _MockHostApi implements FelectronicDnieHostApi {
  DnieSignedDataMessage? signResult;
  PlatformException? signError;
  String? lastSignCan;
  String? lastSignPin;
  String? lastSignCertificateType;

  DnieSignedDataMessage? readCertificateResult;
  String? lastReadCertCan;
  String? lastReadCertPin;
  int? lastReadCertTimeout;
  String? lastReadCertCertificateType;

  DnieCardProbeMessage? probeCardResult;
  DnieCertificateDetailsMessage? certDetailsResult;
  String? lastCertDetailsCertificateType;
  DniePersonalDataMessage? personalDataResult;
  String? lastPersonalDataCertificateType;
  DnieNfcStatusMessage? nfcStatusResult;
  bool stopSignCalled = false;
  bool verifyPinCalled = false;
  String? lastVerifyPinCertificateType;

  @override
  // ignore: non_constant_identifier_names, Pigeon-generated field name.
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  // ignore: non_constant_identifier_names, Pigeon-generated field name.
  String get pigeonVar_messageChannelSuffix => '';

  @override
  Future<DnieSignedDataMessage> sign(
    Uint8List data,
    String can,
    String pin,
    int timeout,
    String certificateType,
  ) async {
    lastSignCan = can;
    lastSignPin = pin;
    lastSignCertificateType = certificateType;
    if (signError != null) throw signError!;
    return signResult!;
  }

  @override
  Future<void> stopSign() async {
    stopSignCalled = true;
  }

  @override
  Future<DnieSignedDataMessage> readCertificate(
    String can,
    String pin,
    int timeout,
    String certificateType,
  ) async {
    lastReadCertCan = can;
    lastReadCertPin = pin;
    lastReadCertTimeout = timeout;
    lastReadCertCertificateType = certificateType;
    return readCertificateResult!;
  }

  @override
  Future<DnieCardProbeMessage> probeCard(int timeout) async =>
      probeCardResult!;

  @override
  Future<DnieCertificateDetailsMessage> readCertificateDetails(
    String can,
    String pin,
    int timeout,
    String certificateType,
  ) async {
    lastCertDetailsCertificateType = certificateType;
    return certDetailsResult!;
  }

  @override
  Future<DniePersonalDataMessage> readPersonalData(
    String can,
    String pin,
    int timeout,
    String certificateType,
  ) async {
    lastPersonalDataCertificateType = certificateType;
    return personalDataResult!;
  }

  @override
  Future<void> verifyPin(
    String can,
    String pin,
    int timeout,
    String certificateType,
  ) async {
    verifyPinCalled = true;
    lastVerifyPinCertificateType = certificateType;
  }

  @override
  Future<DnieNfcStatusMessage> checkNfcAvailability() async =>
      nfcStatusResult!;
}
