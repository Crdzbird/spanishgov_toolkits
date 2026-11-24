import 'package:felectronic_certificates/felectronic_certificates.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_certificates_platform.dart';

void main() {
  late FakeCertificatesPlatform platform;

  setUp(() => platform = FakeCertificatesPlatform.installed());

  group('CertificateSession.select', () {
    test('is null when the native picker is cancelled', () async {
      expect(await CertificateSession.select(), isNull);
    });

    test('wraps the certificate the native picker returns', () async {
      platform.pickedByNativePicker = certificate('07');
      final session = await CertificateSession.select();
      expect(session?.certificate.serialNumber, '07');
    });
  });

  test('delete removes the session certificate by serial', () async {
    platform.pickedByNativePicker = certificate('07');
    await (await CertificateSession.select())!.delete();
    expect(platform.deleted, ['07']);
  });

  test('clear forgets the default but keeps the certificate', () async {
    platform
      ..certificates.add(certificate('07'))
      ..defaultSerial = '07';
    await (await CertificateSession.fromDefault())!.clear();
    expect(platform.defaultSerial, isNull);
    expect(platform.deleted, isEmpty);
  });

  test('a re-import among several resolves by alias', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    platform.certificates.addAll([
      certificate('01', alias: 'work.p12'),
      certificate('02', alias: 'home.p12'),
    ]);
    final session = await AppleCertificates.importAndSelect(
      Uint8List.fromList([0x30]),
      password: 'pw',
      alias: 'home.p12',
    );
    expect(session.certificate.serialNumber, '02');
    expect(platform.defaultSerial, '02');
  });
}
