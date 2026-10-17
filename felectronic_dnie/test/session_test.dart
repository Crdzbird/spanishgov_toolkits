import 'dart:convert';

import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mock_platform.dart';

void main() {
  late MockFelectronicDniePlatform platform;
  final signed = SignedData(
    signedData: utf8.encode('s'),
    signedDataBase64: 'cw==',
    certificate: 'cert',
  );

  setUp(() => platform = installMockPlatform());

  Future<SignedData> platformSign() => platform.sign(
    data: any(named: 'data'),
    can: any(named: 'can'),
    pin: any(named: 'pin'),
    timeout: any(named: 'timeout'),
    certificateType: any(named: 'certificateType'),
  );

  test('rejects malformed credentials before touching NFC', () {
    expect(() => DnieSession(can: '12', pin: 'password1'), throwsArgumentError);
    expect(() => DnieSession(can: '123456', pin: 'short'), throwsArgumentError);
  });

  test('signText signs the UTF-8 bytes with the stored credentials', () async {
    when(platformSign).thenAnswer((_) async => signed);
    final session = DnieSession(can: '123456', pin: 'password1');

    expect(await session.signText('hola'), signed);
    verify(
      () => platform.sign(
        data: utf8.encode('hola'),
        can: '123456',
        pin: 'password1',
      ),
    ).called(1);
  });

  test('auth switches certificate and keeps everything else', () async {
    when(platformSign).thenAnswer((_) async => signed);
    final session = DnieSession(
      can: '123456',
      pin: 'password1',
      timeout: const Duration(seconds: 12),
    );

    final auth = session.auth;
    expect(auth.certificateType, DnieCertificateType.auth);
    expect(auth.timeout, const Duration(seconds: 12));
    expect(auth.signing.certificateType, DnieCertificateType.sign);

    await auth.signText('x');
    verify(
      () => platform.sign(
        data: any(named: 'data'),
        can: '123456',
        pin: 'password1',
        timeout: const Duration(seconds: 12),
        certificateType: DnieCertificateType.auth,
      ),
    ).called(1);
  });

  test('checkReadiness runs with the session credentials', () async {
    when(platform.checkNfcAvailability).thenAnswer(
      (_) async => const NfcStatus(isAvailable: false, isEnabled: false),
    );
    final r = await DnieSession(
      can: '123456',
      pin: 'password1',
    ).checkReadiness();
    expect(r.isReady, isFalse);
  });
}
