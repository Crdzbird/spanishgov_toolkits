import 'dart:typed_data';

import 'package:felectronic_certificates/felectronic_certificates.dart';
import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The Apple-only import path.
///
/// These run on macOS, which `AppleCertificates` supports, so
/// `importAndSelect` is called for real rather than re-implemented in the
/// test. An earlier revision here drove the platform interface directly and
/// therefore verified nothing about the code under test — the empty-password
/// normalisation it claimed to check lives inside `importAndSelect`, and the
/// test was performing that normalisation itself.
///
/// The consequence is that the non-Apple guard cannot be exercised here: on
/// this host `isSupported` is true. It is asserted structurally instead.
void main() {
  late _FakePlatform platform;

  setUp(() {
    platform = _FakePlatform();
    FelectronicCertificatesPlatform.instance = platform;
  });

  Uint8List p12(int seed) => Uint8List.fromList([0x30, 0x82, seed]);

  group('platform guard', () {
    /// Tests run on macOS, which is a supported platform, so the guard cannot
    /// be made to fire here. What can be checked is that macOS is deliberately
    /// included -- the class is for Apple platforms, not iOS alone.
    test('macOS is supported alongside iOS', () {
      expect(AppleCertificates.isSupported, isTrue);
    });
  });

  group('empty keychain explanation', () {
    /// This string exists because an empty list reads as a failure. It has to
    /// name the actual cause or it is no better than the blank list.
    test('names configuration profiles as the usual cause', () {
      final text = AppleCertificates.emptyKeychainExplanation;
      expect(text.toLowerCase(), contains('configuration profile'));
      expect(text.toLowerCase(), contains('system keychain'));
      expect(text, contains('.p12'));
    });
  });

  group('composition', () {
    test('an imported certificate becomes the default', () async {
      final session = await AppleCertificates.importAndSelect(
        p12(1),
        password: 'pw',
      );
      expect(session.certificate.serialNumber, platform.defaultSerial);
    });

    /// An empty password and no password are different things to the Security
    /// framework, and importAndSelect normalises '' to null before the call.
    test('an empty password is normalised away', () async {
      await AppleCertificates.importAndSelect(p12(1), password: '');
      expect(platform.lastPassword, isNull);
    });

    test('a real password is passed through', () async {
      await AppleCertificates.importAndSelect(p12(1), password: 'secret');
      expect(platform.lastPassword, 'secret');
    });

    /// The identity that was not present beforehand is the one selected, even
    /// when the keychain already held others.
    test('the newly imported certificate is the one selected', () async {
      await AppleCertificates.importAndSelect(p12(1), alias: 'first.p12');
      final second = await AppleCertificates.importAndSelect(
        p12(2),
        alias: 'second.p12',
      );
      expect(second.certificate.alias, 'second.p12');
      expect(platform.defaultSerial, second.certificate.serialNumber);
    });

    /// Re-importing the same certificate adds nothing new, so "the one that
    /// was not there before" finds nothing and the fallbacks have to hold.
    test('re-importing the same certificate still resolves', () async {
      await AppleCertificates.importAndSelect(p12(1), alias: 'a.p12');
      final firstCount = platform.certificates.length;

      platform.duplicateNext = true;
      final again = await AppleCertificates.importAndSelect(
        p12(1),
        alias: 'a.p12',
      );

      expect(platform.certificates, hasLength(firstCount));
      expect(
        again.certificate.alias,
        'a.p12',
        reason: 'a duplicate import must resolve by alias, not dead-end',
      );
    });

    /// An import that reports success but leaves nothing behind is a real
    /// failure, not an empty result to be shrugged off.
    test('an import that stores nothing is an error', () async {
      platform.duplicateNext = true;
      await expectLater(
        AppleCertificates.importAndSelect(p12(1)),
        throwsA(isA<CertNotFoundError>()),
      );
    });
  });
}

class _FakePlatform extends FelectronicCertificatesPlatform
    with MockPlatformInterfaceMixin {
  final List<DeviceCertificate> certificates = [];
  final List<Uint8List> imported = [];
  String? lastPassword;
  String? defaultSerial;

  /// Simulates importing a certificate the keychain already holds.
  bool duplicateNext = false;

  var _next = 0;

  @override
  Future<void> importCertificate(
    Uint8List pkcs12Data, {
    String? password,
    String? alias,
  }) async {
    imported.add(pkcs12Data);
    lastPassword = password;
    if (duplicateNext) {
      duplicateNext = false;
      return;
    }
    _next++;
    certificates.add(
      DeviceCertificate(
        serialNumber: '000$_next',
        alias: alias,
        holderName: 'Holder $_next',
        issuerName: 'CA',
        expirationDate: DateTime.utc(2030),
        usages: const [],
        encoded: Uint8List.fromList([0x30, _next]),
      ),
    );
  }

  @override
  Future<List<DeviceCertificate>> getAllCertificates() async => certificates;

  @override
  Future<DeviceCertificate?> getDefaultCertificate() async =>
      certificates.where((c) => c.serialNumber == defaultSerial).firstOrNull;

  @override
  Future<void> setDefaultCertificateBySerialNumber(String serialNumber) async {
    defaultSerial = serialNumber;
  }

  @override
  Future<DeviceCertificate?> selectDefaultCertificate() async => null;

  @override
  Future<void> clearDefaultCertificate() async => defaultSerial = null;

  @override
  Future<Uint8List> signWithDefaultCertificate(
    Uint8List data, {
    CertSignAlgorithm algorithm = CertSignAlgorithm.sha256rsa,
  }) async => Uint8List.fromList([1]);

  @override
  Future<void> deleteDefaultCertificate() async {}

  @override
  Future<void> deleteCertificateBySerialNumber(String serialNumber) async {}
}
