import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/signing_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SigningApi api;
  late MethodChannelFelectronicDnie platform;

  setUp(() {
    api = SigningApi();
    platform = MethodChannelFelectronicDnie()..api = api;
  });

  Future<SignedData> signCades() => platform.signCades(
    data: Uint8List(4),
    can: '123456',
    pin: 'password1',
    timeout: const Duration(seconds: 12),
    certificateType: DnieCertificateType.auth,
  );

  test('sign and signCades reach separate native calls', () async {
    final raw = await platform.sign(
      data: Uint8List(4),
      can: '123456',
      pin: 'password1',
      certificateType: DnieCertificateType.auth,
    );
    final cades = await signCades();

    expect(raw.signedData, [1, 2, 3]);
    expect(cades.signedData, [48, 128]);
    expect(api.calls, [
      'sign 123456 password1 30 AUTH 4',
      'signCades 123456 password1 12 AUTH 4',
    ]);
  });

  test(
    'signCades answers DnieUnsupportedError where the platform lacks it',
    () {
      api.error = PlatformException(
        code: 'DSUnsupportedException',
        message: 'Only on Android.',
      );
      expect(
        signCades(),
        throwsA(
          isA<DnieUnsupportedError>().having(
            (e) => e.message,
            'message',
            'Only on Android.',
          ),
        ),
      );
    },
  );

  test('signCades maps a wrong PIN like sign does', () {
    api.error = PlatformException(
      code: 'DSDNIeWrongPINException',
      message: '2',
    );
    expect(
      signCades(),
      throwsA(
        isA<DnieWrongPinError>().having(
          (e) => e.remainingRetries,
          'retries',
          2,
        ),
      ),
    );
  });
}
