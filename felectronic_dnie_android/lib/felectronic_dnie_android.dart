import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';

/// The Android implementation of [FelectronicDniePlatform].
///
/// Everything is inherited from [MethodChannelFelectronicDnie]: both
/// platforms answer the same Pigeon API, so this class only registers itself.
final class FelectronicDnieAndroid extends MethodChannelFelectronicDnie {
  /// Registers this class as the default instance of
  /// [FelectronicDniePlatform].
  static void registerWith() {
    FelectronicDniePlatform.instance = FelectronicDnieAndroid();
  }
}
