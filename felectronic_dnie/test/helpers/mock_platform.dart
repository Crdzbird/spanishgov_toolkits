import 'dart:typed_data';

import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFelectronicDniePlatform extends Mock
    with MockPlatformInterfaceMixin
    implements FelectronicDniePlatform {}

MockFelectronicDniePlatform installMockPlatform() {
  registerFallbackValue(Uint8List(0));
  registerFallbackValue(DnieCertificateType.sign);
  final platform = MockFelectronicDniePlatform();
  FelectronicDniePlatform.instance = platform;
  return platform;
}

const readyNfc = NfcStatus(isAvailable: true, isEnabled: true);

const dnieProbe = CardProbeResult(
  isValidDnie: true,
  atrHex: 'E1F35E11',
  tagId: '937DBA1D',
);
