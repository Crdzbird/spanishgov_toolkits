import 'package:felectronic_dnie_platform_interface/src/generated/messages.g.dart';
import 'package:felectronic_dnie_platform_interface/src/models/nfc_status.dart';

/// Converts the Pigeon [DnieNfcStatusMessage] into an [NfcStatus].
extension DnieNfcStatusMessageMapper on DnieNfcStatusMessage {
  /// The [NfcStatus] this message carries.
  NfcStatus toModel() =>
      NfcStatus(isAvailable: isAvailable, isEnabled: isEnabled);
}
