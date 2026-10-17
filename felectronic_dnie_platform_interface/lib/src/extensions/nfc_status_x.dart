import 'package:felectronic_dnie_platform_interface/src/models/nfc_status.dart';
import 'package:felectronic_dnie_platform_interface/src/models/nfc_status_type.dart';

/// Convenience extensions on [NfcStatus].
extension NfcStatusX on NfcStatus {
  /// Whether NFC is available and enabled, so operations can run.
  bool get isReady => isAvailable && isEnabled;

  /// The structured NFC status as an enum value.
  NfcStatusType get statusType {
    if (!isAvailable) return NfcStatusType.unavailable;
    if (!isEnabled) return NfcStatusType.disabled;
    return NfcStatusType.ready;
  }

  /// Human-readable NFC status message.
  String get statusMessage => statusType.message;
}
