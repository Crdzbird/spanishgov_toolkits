import 'package:felectronic_dnie_android/felectronic_dnie_android.dart';
import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FelectronicDnieAndroid', () {
    test('can be registered', () {
      FelectronicDnieAndroid.registerWith();
      expect(FelectronicDniePlatform.instance, isA<FelectronicDnieAndroid>());
    });

    test('uses the shared Pigeon implementation', () {
      expect(FelectronicDnieAndroid(), isA<MethodChannelFelectronicDnie>());
    });
  });
}
