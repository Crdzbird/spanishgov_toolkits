import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mock_platform.dart';

void main() {
  late MockFelectronicDniePlatform platform;

  setUp(() => platform = installMockPlatform());

  test('probeCard forwards the timeout and returns the probe', () async {
    const timeout = Duration(seconds: 5);
    when(
      () => platform.probeCard(timeout: any(named: 'timeout')),
    ).thenAnswer((_) async => dnieProbe);

    expect(await probeCard(timeout: timeout), dnieProbe);
    verify(() => platform.probeCard(timeout: timeout)).called(1);
  });

  test('stopSign forwards to the platform', () async {
    when(platform.stopSign).thenAnswer((_) async {});
    await stopSign();
    verify(platform.stopSign).called(1);
  });

  test('checkNfcAvailability returns the platform status', () async {
    const disabled = NfcStatus(isAvailable: true, isEnabled: false);
    when(platform.checkNfcAvailability).thenAnswer((_) async => disabled);

    final status = await checkNfcAvailability();
    expect(status, disabled);
    expect(status.isReady, isFalse);
    expect(status.statusType, NfcStatusType.disabled);
  });
}
