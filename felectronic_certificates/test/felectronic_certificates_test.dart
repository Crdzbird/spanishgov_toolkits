import 'dart:typed_data';

import 'package:felectronic_certificates/felectronic_certificates.dart';
import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFelectronicCertificatesPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements FelectronicCertificatesPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFelectronicCertificatesPlatform mockPlatform;

  final testCertificate = DeviceCertificate(
    serialNumber: 'abc123',
    holderName: 'GARCIA, JUAN',
    issuerName: 'FNMT',
    expirationDate: DateTime(2030),
    usages: const [CertKeyUsage.signing],
    encoded: Uint8List.fromList([1, 2, 3]),
  );

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(CertSignAlgorithm.sha256rsa);
  });

  setUp(() {
    mockPlatform = MockFelectronicCertificatesPlatform();
    FelectronicCertificatesPlatform.instance = mockPlatform;
  });

  group('felectronic_certificates', () {
    group('getAllCertificates', () {
      test('delegates to platform', () async {
        when(
          () => mockPlatform.getAllCertificates(),
        ).thenAnswer((_) async => [testCertificate]);

        final result = await getAllCertificates();

        expect(result, [testCertificate]);
        verify(() => mockPlatform.getAllCertificates()).called(1);
      });
    });

    group('getDefaultCertificate', () {
      test('delegates to platform', () async {
        when(
          () => mockPlatform.getDefaultCertificate(),
        ).thenAnswer((_) async => testCertificate);

        final result = await getDefaultCertificate();

        expect(result, testCertificate);
        verify(() => mockPlatform.getDefaultCertificate()).called(1);
      });

      test('returns null when none selected', () async {
        when(
          () => mockPlatform.getDefaultCertificate(),
        ).thenAnswer((_) async => null);

        final result = await getDefaultCertificate();

        expect(result, isNull);
      });
    });

    group('selectDefaultCertificate', () {
      test('delegates to platform', () async {
        when(
          () => mockPlatform.selectDefaultCertificate(),
        ).thenAnswer((_) async => testCertificate);

        final result = await selectDefaultCertificate();

        expect(result, testCertificate);
        verify(() => mockPlatform.selectDefaultCertificate()).called(1);
      });
    });

    group('setDefaultCertificateBySerialNumber', () {
      test('delegates to platform', () async {
        when(
          () => mockPlatform.setDefaultCertificateBySerialNumber(
            any(),
          ),
        ).thenAnswer((_) async {});

        await setDefaultCertificateBySerialNumber('abc123');

        verify(
          () => mockPlatform.setDefaultCertificateBySerialNumber('abc123'),
        ).called(1);
      });
    });

    group('clearDefaultCertificate', () {
      test('delegates to platform', () async {
        when(
          () => mockPlatform.clearDefaultCertificate(),
        ).thenAnswer((_) async {});

        await clearDefaultCertificate();

        verify(() => mockPlatform.clearDefaultCertificate()).called(1);
      });
    });

    group('signWithDefaultCertificate', () {
      test('delegates to platform with default algorithm', () async {
        when(
          () => mockPlatform.signWithDefaultCertificate(
            any(),
            algorithm: any(named: 'algorithm'),
          ),
        ).thenAnswer((_) async => Uint8List.fromList([10, 20]));

        final result = await signWithDefaultCertificate(
          Uint8List.fromList([42]),
        );

        expect(result, Uint8List.fromList([10, 20]));
        verify(
          () => mockPlatform.signWithDefaultCertificate(
            any(),
          ),
        ).called(1);
      });

      test('passes custom algorithm', () async {
        when(
          () => mockPlatform.signWithDefaultCertificate(
            any(),
            algorithm: any(named: 'algorithm'),
          ),
        ).thenAnswer((_) async => Uint8List.fromList([10, 20]));

        await signWithDefaultCertificate(
          Uint8List.fromList([42]),
          algorithm: CertSignAlgorithm.sha512ec,
        );

        verify(
          () => mockPlatform.signWithDefaultCertificate(
            any(),
            algorithm: CertSignAlgorithm.sha512ec,
          ),
        ).called(1);
      });
    });

    group('importCertificate', () {
      test('delegates to platform', () async {
        when(
          () => mockPlatform.importCertificate(
            any(),
            password: any(named: 'password'),
            alias: any(named: 'alias'),
          ),
        ).thenAnswer((_) async {});

        await importCertificate(
          Uint8List.fromList([1, 2, 3]),
          password: 'secret',
          alias: 'myAlias',
        );

        verify(
          () => mockPlatform.importCertificate(
            any(),
            password: 'secret',
            alias: 'myAlias',
          ),
        ).called(1);
      });
    });

    group('deleteDefaultCertificate', () {
      test('delegates to platform', () async {
        when(
          () => mockPlatform.deleteDefaultCertificate(),
        ).thenAnswer((_) async {});

        await deleteDefaultCertificate();

        verify(() => mockPlatform.deleteDefaultCertificate()).called(1);
      });
    });

    group('deleteCertificateBySerialNumber', () {
      test('delegates to platform', () async {
        when(
          () => mockPlatform.deleteCertificateBySerialNumber(any()),
        ).thenAnswer((_) async {});

        await deleteCertificateBySerialNumber('abc123');

        verify(
          () => mockPlatform.deleteCertificateBySerialNumber('abc123'),
        ).called(1);
      });
    });
  });
}
