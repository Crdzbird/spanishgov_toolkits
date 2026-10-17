import 'package:felectronic_dnie/felectronic_dnie.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mock_platform.dart';

void main() {
  late MockFelectronicDniePlatform platform;

  setUp(() => platform = installMockPlatform());

  test('operations ignore whitespace around the CAN and PIN', () async {
    when(
      () => platform.verifyPin(
        can: any(named: 'can'),
        pin: any(named: 'pin'),
        timeout: any(named: 'timeout'),
        certificateType: any(named: 'certificateType'),
      ),
    ).thenAnswer((_) async {});

    await verifyPin(can: ' 123456 ', pin: ' password1\n');

    verify(
      () => platform.verifyPin(
        can: '123456',
        pin: 'password1',
      ),
    ).called(1);
  });
}
