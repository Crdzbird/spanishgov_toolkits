import 'package:felectronic_certificates_ios/felectronic_certificates_ios.dart';
import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FelectronicCertificatesIOS', () {
    late FelectronicCertificatesIOS platform;
    late _MockHostApi mockApi;

    setUp(() {
      platform = FelectronicCertificatesIOS();
      mockApi = _MockHostApi();
      platform.api = mockApi;
    });

    test('can be registered', () {
      FelectronicCertificatesIOS.registerWith();
      expect(
        FelectronicCertificatesPlatform.instance,
        isA<FelectronicCertificatesIOS>(),
      );
    });

    test('getAllCertificates returns list', () async {
      mockApi.allCertificatesResult = [
        DeviceCertificateMessage(
          serialNumber: 'abc123',
          holderName: 'GARCIA, JUAN',
          issuerName: 'FNMT',
          expirationDate: '31-12-2030',
          usages: 'SIGNING;AUTHENTICATION',
          encoded: Uint8List.fromList([1, 2, 3]),
        ),
      ];

      final result = await platform.getAllCertificates();
      expect(result, hasLength(1));
      expect(result.first.serialNumber, 'abc123');
      expect(result.first.expirationDate, DateTime(2030, 12, 31));
      expect(
        result.first.usages,
        [CertKeyUsage.signing, CertKeyUsage.authentication],
      );
    });

    test('getDefaultCertificate returns certificate', () async {
      mockApi.defaultCertificateResult = DeviceCertificateMessage(
        serialNumber: 'def456',
        alias: 'Work Cert',
        holderName: 'LOPEZ, MARIA',
        issuerName: 'FNMT',
        expirationDate: '15-06-2028',
        usages: 'AUTHENTICATION',
        encoded: Uint8List.fromList([4, 5, 6]),
      );

      final result = await platform.getDefaultCertificate();
      expect(result, isNotNull);
      expect(result!.alias, 'Work Cert');
    });

    test('getDefaultCertificate returns null', () async {
      final result = await platform.getDefaultCertificate();
      expect(result, isNull);
    });

    test('selectDefaultCertificate returns certificate', () async {
      mockApi.selectCertificateResult = DeviceCertificateMessage(
        serialNumber: 'ghi789',
        holderName: 'PEREZ, CARLOS',
        issuerName: 'FNMT',
        expirationDate: '01-01-2029',
        usages: 'ENCRYPTION',
        encoded: Uint8List.fromList([7, 8, 9]),
      );

      final result = await platform.selectDefaultCertificate();
      expect(result, isNotNull);
      expect(result!.usages, [CertKeyUsage.encryption]);
    });

    test('setDefaultCertificateBySerialNumber passes serial', () async {
      await platform.setDefaultCertificateBySerialNumber('abc123');
      expect(mockApi.lastSetSerial, 'abc123');
    });

    test('clearDefaultCertificate invokes method', () async {
      await platform.clearDefaultCertificate();
      expect(mockApi.clearDefaultCalled, isTrue);
    });

    test('signWithDefaultCertificate returns bytes', () async {
      mockApi.signResult = Uint8List.fromList([10, 20, 30]);

      final result = await platform.signWithDefaultCertificate(
        Uint8List.fromList([42]),
      );
      expect(result, Uint8List.fromList([10, 20, 30]));
      expect(mockApi.lastSignAlgorithm, 'SHA256RSA');
    });

    test('signWithDefaultCertificate passes SHA256EC', () async {
      mockApi.signResult = Uint8List.fromList([10]);

      await platform.signWithDefaultCertificate(
        Uint8List.fromList([42]),
        algorithm: CertSignAlgorithm.sha256ec,
      );
      expect(mockApi.lastSignAlgorithm, 'SHA256EC');
    });

    test('importCertificate passes data', () async {
      await platform.importCertificate(
        Uint8List.fromList([1, 2]),
        password: 'pass',
        alias: 'test',
      );
      expect(mockApi.lastImportPassword, 'pass');
      expect(mockApi.lastImportAlias, 'test');
    });

    test('deleteDefaultCertificate invokes method', () async {
      await platform.deleteDefaultCertificate();
      expect(mockApi.deleteDefaultCalled, isTrue);
    });

    test('deleteCertificateBySerialNumber passes serial', () async {
      await platform.deleteCertificateBySerialNumber('abc123');
      expect(mockApi.lastDeleteSerial, 'abc123');
    });

    test('signWithDefaultCertificate throws CertSigningError', () async {
      mockApi.signError = PlatformException(
        code: 'SigningError',
        message: 'Failed',
      );

      expect(
        () => platform.signWithDefaultCertificate(Uint8List(1)),
        throwsA(isA<CertSigningError>()),
      );
    });

    test('importCertificate throws CertIncorrectPasswordError', () async {
      mockApi.importError = PlatformException(
        code: 'IncorrectPassword',
        message: 'Bad password',
      );

      expect(
        () => platform.importCertificate(Uint8List(1), password: 'wrong'),
        throwsA(isA<CertIncorrectPasswordError>()),
      );
    });
  });
}

class _MockHostApi implements FelectronicCertificatesHostApi {
  List<DeviceCertificateMessage?>? allCertificatesResult;
  DeviceCertificateMessage? defaultCertificateResult;
  DeviceCertificateMessage? selectCertificateResult;
  Uint8List? signResult;
  PlatformException? signError;
  PlatformException? importError;

  String? lastSetSerial;
  bool clearDefaultCalled = false;
  String? lastSignAlgorithm;
  String? lastImportPassword;
  String? lastImportAlias;
  bool deleteDefaultCalled = false;
  String? lastDeleteSerial;

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
      defaultCertificateResult;

  @override
  Future<DeviceCertificateMessage?> selectDefaultCertificate() async =>
      selectCertificateResult;

  @override
  Future<void> setDefaultCertificateBySerialNumber(
    String serialNumber,
  ) async {
    lastSetSerial = serialNumber;
  }

  @override
  Future<void> clearDefaultCertificate() async {
    clearDefaultCalled = true;
  }

  @override
  Future<Uint8List> signWithDefaultCertificate(
    Uint8List data,
    String algorithm,
  ) async {
    lastSignAlgorithm = algorithm;
    if (signError != null) throw signError!;
    return signResult!;
  }

  @override
  Future<void> importCertificate(
    Uint8List pkcs12Data,
    String? password,
    String? alias,
  ) async {
    lastImportPassword = password;
    lastImportAlias = alias;
    if (importError != null) throw importError!;
  }

  @override
  Future<void> deleteDefaultCertificate() async {
    deleteDefaultCalled = true;
  }

  @override
  Future<void> deleteCertificateBySerialNumber(String serialNumber) async {
    lastDeleteSerial = serialNumber;
  }
}
