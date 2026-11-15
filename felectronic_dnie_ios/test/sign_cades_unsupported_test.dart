import 'package:felectronic_dnie_ios/felectronic_dnie_ios.dart';
import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Api extends FelectronicDnieHostApi {
  @override
  Future<DnieSignedDataMessage> signCades(
    Uint8List data,
    String can,
    String pin,
    int timeout,
    String certificateType,
  ) => Future.error(
    PlatformException(
      code: 'DSUnsupportedException',
      message: 'signCades is only available on Android.',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('signCades answers DnieUnsupportedError, as the plugin does', () {
    final platform = FelectronicDnieIOS()..api = _Api();
    expect(
      platform.signCades(data: Uint8List(1), can: '123456', pin: 'password1'),
      throwsA(
        isA<DnieUnsupportedError>().having(
          (e) => e.message,
          'message',
          'signCades is only available on Android.',
        ),
      ),
    );
  });
}
