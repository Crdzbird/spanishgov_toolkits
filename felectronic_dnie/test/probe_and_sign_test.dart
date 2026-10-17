import 'dart:typed_data';

import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mock_platform.dart';

void main() {
  late MockFelectronicDniePlatform platform;

  setUp(() => platform = installMockPlatform());

  Future<SignedData> signIt() =>
      probeAndSign(data: Uint8List(1), can: '123456', pin: 'password1');

  Future<SignedData> platformSign() => platform.sign(
    data: any(named: 'data'),
    can: any(named: 'can'),
    pin: any(named: 'pin'),
    timeout: any(named: 'timeout'),
    certificateType: any(named: 'certificateType'),
  );

  void stubProbe(CardProbeResult probe) => when(
    () => platform.probeCard(timeout: any(named: 'timeout')),
  ).thenAnswer((_) async => probe);

  test('throws DnieNotDnieError and never signs a non-DNIe card', () async {
    stubProbe(
      const CardProbeResult(isValidDnie: false, atrHex: '', tagId: ''),
    );
    await expectLater(signIt(), throwsA(isA<DnieNotDnieError>()));
    verifyNever(platformSign);
  });

  test('signs once the probe confirms a DNIe', () async {
    final signed = SignedData(
      signedData: Uint8List(2),
      signedDataBase64: 'AAA=',
      certificate: 'cert',
    );
    stubProbe(dnieProbe);
    when(platformSign).thenAnswer((_) async => signed);
    expect(await signIt(), signed);
  });
}
