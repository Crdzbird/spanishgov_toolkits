import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mock_platform.dart';

void main() {
  late MockFelectronicDniePlatform platform;

  setUp(() => platform = installMockPlatform());

  void stubNfc(NfcStatus status) =>
      when(platform.checkNfcAvailability).thenAnswer((_) async => status);

  void stubProbe(CardProbeResult probe) => when(
    () => platform.probeCard(timeout: any(named: 'timeout')),
  ).thenAnswer((_) async => probe);

  When<Future<void>> whenVerify() => when(
    () => platform.verifyPin(
      can: any(named: 'can'),
      pin: any(named: 'pin'),
      timeout: any(named: 'timeout'),
      certificateType: any(named: 'certificateType'),
    ),
  );

  Future<DnieReadiness> check() =>
      checkReadiness(can: '123456', pin: 'password1');

  group('checkReadiness', () {
    test('stops at NFC when it is disabled', () async {
      stubNfc(const NfcStatus(isAvailable: true, isEnabled: false));
      final r = await check();
      expect(r.isReady, isFalse);
      expect(r.isValidDnie, isFalse);
      verifyNever(() => platform.probeCard(timeout: any(named: 'timeout')));
    });

    test('stops at the probe when the card is not a DNIe', () async {
      stubNfc(readyNfc);
      stubProbe(
        const CardProbeResult(isValidDnie: false, atrHex: 'AA', tagId: 'BB'),
      );
      final r = await check();
      expect(r.isValidDnie, isFalse);
      expect(r.atrHex, 'AA');
      expect(r.error, isNull);
    });

    test('captures a wrong PIN instead of throwing', () async {
      stubNfc(readyNfc);
      stubProbe(dnieProbe);
      whenVerify().thenThrow(const DnieWrongPinError(remainingRetries: 2));
      final r = await check();
      expect(r.isValidDnie, isTrue);
      expect(r.isPinCorrect, isFalse);
      expect(r.error, isA<DnieWrongPinError>());
    });

    test('is ready when every step passes', () async {
      stubNfc(readyNfc);
      stubProbe(dnieProbe);
      whenVerify().thenAnswer((_) async {});
      final r = await check();
      expect(r.isReady, isTrue);
      expect(r.tagId, '937DBA1D');
    });

    test('reports NFC as unavailable when the check itself fails', () async {
      when(
        platform.checkNfcAvailability,
      ).thenThrow(const DnieUnknownError('x'));
      final r = await check();
      expect(r.nfcStatus.isAvailable, isFalse);
      expect(r.error, isA<DnieUnknownError>());
    });
  });
}
