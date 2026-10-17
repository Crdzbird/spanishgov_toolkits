import 'package:felectronic_dnie_ios/felectronic_dnie_ios.dart';
import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FelectronicDnieIOS', () {
    test('can be registered', () {
      FelectronicDnieIOS.registerWith();
      expect(FelectronicDniePlatform.instance, isA<FelectronicDnieIOS>());
    });

    test('uses the shared Pigeon implementation', () {
      expect(FelectronicDnieIOS(), isA<MethodChannelFelectronicDnie>());
    });
  });
}
