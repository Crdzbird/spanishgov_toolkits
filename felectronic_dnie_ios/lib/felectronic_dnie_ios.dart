import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';

/// The iOS implementation of [FelectronicDniePlatform].
///
/// Everything is inherited from [MethodChannelFelectronicDnie]: both
/// platforms answer the same Pigeon API, so this class only registers itself.
final class FelectronicDnieIOS extends MethodChannelFelectronicDnie {
  /// Registers this class as the default instance of
  /// [FelectronicDniePlatform].
  static void registerWith() {
    FelectronicDniePlatform.instance = FelectronicDnieIOS();
  }
}
