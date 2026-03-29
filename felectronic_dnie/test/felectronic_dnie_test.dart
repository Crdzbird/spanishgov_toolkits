import 'dart:typed_data';

import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFelectronicDniePlatform extends Mock
    with MockPlatformInterfaceMixin
    implements FelectronicDniePlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFelectronicDniePlatform mockPlatform;

  final testResult = SignedData(
    signedData: Uint8List.fromList([10, 20]),
    signedDataBase64: 'ChQ=',
    certificate: 'testCert',
  );

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(DnieCertificateType.sign);
  });

  setUp(() {
    mockPlatform = MockFelectronicDniePlatform();
    FelectronicDniePlatform.instance = mockPlatform;
  });

  group('felectronic_dnie', () {
    group('sign', () {
      test('delegates to platform', () async {
        when(
          () => mockPlatform.sign(
            data: any(named: 'data'),
            can: any(named: 'can'),
            pin: any(named: 'pin'),
            timeout: any(named: 'timeout'),
            certificateType: any(named: 'certificateType'),
          ),
        ).thenAnswer((_) async => testResult);

        final result = await sign(
          data: Uint8List.fromList([1, 2, 3]),
          can: '123456',
          pin: 'myPin123',
        );

        expect(result, testResult);
        verify(
          () => mockPlatform.sign(
            data: any(named: 'data'),
            can: '123456',
            pin: 'myPin123',
          ),
        ).called(1);
      });

      test('passes auth certificate type', () async {
        when(
          () => mockPlatform.sign(
            data: any(named: 'data'),
            can: any(named: 'can'),
            pin: any(named: 'pin'),
            timeout: any(named: 'timeout'),
            certificateType: any(named: 'certificateType'),
          ),
        ).thenAnswer((_) async => testResult);

        await sign(
          data: Uint8List.fromList([1, 2, 3]),
          can: '123456',
          pin: 'myPin123',
          certificateType: DnieCertificateType.auth,
        );

        verify(
          () => mockPlatform.sign(
            data: any(named: 'data'),
            can: '123456',
            pin: 'myPin123',
            certificateType: DnieCertificateType.auth,
          ),
        ).called(1);
      });
    });

    group('stopSign', () {
      test('delegates to platform', () async {
        when(() => mockPlatform.stopSign()).thenAnswer((_) async {});
        await stopSign();
        verify(() => mockPlatform.stopSign()).called(1);
      });
    });

    group('readCertificate', () {
      test('delegates to platform', () async {
        when(
          () => mockPlatform.readCertificate(
            can: any(named: 'can'),
            pin: any(named: 'pin'),
            timeout: any(named: 'timeout'),
            certificateType: any(named: 'certificateType'),
          ),
        ).thenAnswer((_) async => testResult);

        final result = await readCertificate(
          can: '654321',
          pin: 'myPin456',
        );

        expect(result, testResult);
        verify(
          () => mockPlatform.readCertificate(
            can: '654321',
            pin: 'myPin456',
          ),
        ).called(1);
      });

      test('passes auth certificate type', () async {
        when(
          () => mockPlatform.readCertificate(
            can: any(named: 'can'),
            pin: any(named: 'pin'),
            timeout: any(named: 'timeout'),
            certificateType: any(named: 'certificateType'),
          ),
        ).thenAnswer((_) async => testResult);

        await readCertificate(
          can: '654321',
          pin: 'myPin456',
          certificateType: DnieCertificateType.auth,
        );

        verify(
          () => mockPlatform.readCertificate(
            can: '654321',
            pin: 'myPin456',
            certificateType: DnieCertificateType.auth,
          ),
        ).called(1);
      });
    });

    group('probeCard', () {
      test('delegates to platform', () async {
        const probeResult = CardProbeResult(
          isValidDnie: true,
          atrHex: 'E1F35E11',
          tagId: 'ABCD1234',
        );
        when(
          () => mockPlatform.probeCard(timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => probeResult);

        final result = await probeCard();

        expect(result, probeResult);
        verify(() => mockPlatform.probeCard()).called(1);
      });
    });

    group('readCertificateDetails', () {
      test('delegates to platform', () async {
        final certInfo = CertificateInfo(
          subjectCommonName: 'GARCIA, JUAN (FIRMA)',
          subjectSerialNumber: '12345678Z',
          issuerCommonName: 'AC DNIE',
          issuerOrganization: 'FNMT',
          notValidBefore: DateTime(2021),
          notValidAfter: DateTime(2030),
          serialNumber: 'abc',
          isCurrentlyValid: true,
        );
        when(
          () => mockPlatform.readCertificateDetails(
            can: any(named: 'can'),
            pin: any(named: 'pin'),
            timeout: any(named: 'timeout'),
            certificateType: any(named: 'certificateType'),
          ),
        ).thenAnswer((_) async => certInfo);

        final result = await readCertificateDetails(
          can: '123456',
          pin: 'myPin',
        );

        expect(result, certInfo);
      });

      test('passes auth certificate type', () async {
        final certInfo = CertificateInfo(
          subjectCommonName: 'GARCIA, JUAN (AUTENTICACION)',
          subjectSerialNumber: '12345678Z',
          issuerCommonName: 'AC DNIE',
          issuerOrganization: 'FNMT',
          notValidBefore: DateTime(2021),
          notValidAfter: DateTime(2030),
          serialNumber: 'abc',
          isCurrentlyValid: true,
        );
        when(
          () => mockPlatform.readCertificateDetails(
            can: any(named: 'can'),
            pin: any(named: 'pin'),
            timeout: any(named: 'timeout'),
            certificateType: any(named: 'certificateType'),
          ),
        ).thenAnswer((_) async => certInfo);

        await readCertificateDetails(
          can: '123456',
          pin: 'myPin',
          certificateType: DnieCertificateType.auth,
        );

        verify(
          () => mockPlatform.readCertificateDetails(
            can: '123456',
            pin: 'myPin',
            certificateType: DnieCertificateType.auth,
          ),
        ).called(1);
      });
    });

    group('readPersonalData', () {
      test('delegates to platform', () async {
        const personalData = PersonalData(
          fullName: 'JUAN GARCIA',
          givenName: 'JUAN',
          surnames: 'GARCIA',
          nif: '12345678Z',
          country: 'ES',
          certificateType: 'FIRMA',
        );
        when(
          () => mockPlatform.readPersonalData(
            can: any(named: 'can'),
            pin: any(named: 'pin'),
            timeout: any(named: 'timeout'),
            certificateType: any(named: 'certificateType'),
          ),
        ).thenAnswer((_) async => personalData);

        final result = await readPersonalData(
          can: '123456',
          pin: 'myPin',
        );

        expect(result, personalData);
      });

      test('passes auth certificate type', () async {
        const personalData = PersonalData(
          fullName: 'JUAN GARCIA',
          givenName: 'JUAN',
          surnames: 'GARCIA',
          nif: '12345678Z',
          country: 'ES',
          certificateType: 'AUTENTICACION',
        );
        when(
          () => mockPlatform.readPersonalData(
            can: any(named: 'can'),
            pin: any(named: 'pin'),
            timeout: any(named: 'timeout'),
            certificateType: any(named: 'certificateType'),
          ),
        ).thenAnswer((_) async => personalData);

        await readPersonalData(
          can: '123456',
          pin: 'myPin',
          certificateType: DnieCertificateType.auth,
        );

        verify(
          () => mockPlatform.readPersonalData(
            can: '123456',
            pin: 'myPin',
            certificateType: DnieCertificateType.auth,
          ),
        ).called(1);
      });
    });

    group('verifyPin', () {
      test('delegates to platform', () async {
        when(
          () => mockPlatform.verifyPin(
            can: any(named: 'can'),
            pin: any(named: 'pin'),
            timeout: any(named: 'timeout'),
            certificateType: any(named: 'certificateType'),
          ),
        ).thenAnswer((_) async {});

        await verifyPin(can: '123456', pin: 'myPin');

        verify(
          () => mockPlatform.verifyPin(
            can: '123456',
            pin: 'myPin',
          ),
        ).called(1);
      });

      test('passes auth certificate type', () async {
        when(
          () => mockPlatform.verifyPin(
            can: any(named: 'can'),
            pin: any(named: 'pin'),
            timeout: any(named: 'timeout'),
            certificateType: any(named: 'certificateType'),
          ),
        ).thenAnswer((_) async {});

        await verifyPin(
          can: '123456',
          pin: 'myPin',
          certificateType: DnieCertificateType.auth,
        );

        verify(
          () => mockPlatform.verifyPin(
            can: '123456',
            pin: 'myPin',
            certificateType: DnieCertificateType.auth,
          ),
        ).called(1);
      });
    });

    group('checkNfcAvailability', () {
      test('delegates to platform', () async {
        const nfcStatus = NfcStatus(isAvailable: true, isEnabled: true);
        when(
          () => mockPlatform.checkNfcAvailability(),
        ).thenAnswer((_) async => nfcStatus);

        final result = await checkNfcAvailability();

        expect(result, nfcStatus);
        verify(() => mockPlatform.checkNfcAvailability()).called(1);
      });

      test('returns disabled NFC status', () async {
        const nfcStatus = NfcStatus(isAvailable: true, isEnabled: false);
        when(
          () => mockPlatform.checkNfcAvailability(),
        ).thenAnswer((_) async => nfcStatus);

        final result = await checkNfcAvailability();

        expect(result.isAvailable, isTrue);
        expect(result.isEnabled, isFalse);
      });

      test('returns unavailable NFC status', () async {
        const nfcStatus = NfcStatus(isAvailable: false, isEnabled: false);
        when(
          () => mockPlatform.checkNfcAvailability(),
        ).thenAnswer((_) async => nfcStatus);

        final result = await checkNfcAvailability();

        expect(result.isAvailable, isFalse);
        expect(result.isEnabled, isFalse);
      });
    });
  });
}
