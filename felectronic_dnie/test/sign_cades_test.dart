import 'dart:typed_data';

import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mock_platform.dart';

void main() {
  late MockFelectronicDniePlatform platform;
  final raw = SignedData(
    signedData: Uint8List.fromList([1, 2]),
    signedDataBase64: 'AQI=',
    certificate: 'Y2VydA==',
  );
  final cades = SignedData(
    signedData: Uint8List.fromList([48, 128]),
    signedDataBase64: 'MIA=',
    certificate: 'Y2VydA==',
  );

  setUp(() {
    platform = installMockPlatform();
    when(
      () => platform.sign(
        data: any(named: 'data'),
        can: any(named: 'can'),
        pin: any(named: 'pin'),
        timeout: any(named: 'timeout'),
        certificateType: any(named: 'certificateType'),
      ),
    ).thenAnswer((_) async => raw);
    when(
      () => platform.signCades(
        data: any(named: 'data'),
        can: any(named: 'can'),
        pin: any(named: 'pin'),
        timeout: any(named: 'timeout'),
        certificateType: any(named: 'certificateType'),
      ),
    ).thenAnswer((_) async => cades);
  });

  test('sign and signCades reach their own platform call', () async {
    final data = Uint8List(3);
    expect(await sign(data: data, can: '123456', pin: 'password1'), raw);
    expect(
      await signCades(data: data, can: ' 123456 ', pin: 'password1\n'),
      cades,
    );
    verify(
      () => platform.signCades(data: data, can: '123456', pin: 'password1'),
    ).called(1);
  });

  test('DnieSession.signCades keeps the session settings', () async {
    final session = DnieSession(
      can: '123456',
      pin: 'password1',
      timeout: const Duration(seconds: 12),
    ).auth;

    expect(await session.signCades(Uint8List(1)), cades);
    verify(
      () => platform.signCades(
        data: any(named: 'data'),
        can: '123456',
        pin: 'password1',
        timeout: const Duration(seconds: 12),
        certificateType: DnieCertificateType.auth,
      ),
    ).called(1);
  });

  test('signCades passes DnieUnsupportedError through', () async {
    when(
      () => platform.signCades(
        data: any(named: 'data'),
        can: any(named: 'can'),
        pin: any(named: 'pin'),
        timeout: any(named: 'timeout'),
        certificateType: any(named: 'certificateType'),
      ),
    ).thenAnswer((_) async => throw const DnieUnsupportedError());
    await expectLater(
      signCades(data: Uint8List(1), can: '123456', pin: 'password1'),
      throwsA(isA<DnieUnsupportedError>()),
    );
  });
}
