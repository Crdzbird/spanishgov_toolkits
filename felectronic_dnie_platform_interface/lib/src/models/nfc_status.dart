import 'package:flutter/foundation.dart';

/// {@template nfc_status}
/// The NFC hardware status of the current device.
///
/// Use [isAvailable] to check if the device has NFC hardware,
/// and [isEnabled] to check if NFC is turned on in system settings.
/// {@endtemplate}
@immutable
class NfcStatus {
  /// {@macro nfc_status}
  const NfcStatus({
    required this.isAvailable,
    required this.isEnabled,
  });

  /// Whether the device has NFC hardware.
  final bool isAvailable;

  /// Whether NFC is enabled in system settings.
  ///
  /// On iOS this always matches [isAvailable] since NFC
  /// cannot be toggled independently.
  final bool isEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NfcStatus &&
          other.isAvailable == isAvailable &&
          other.isEnabled == isEnabled;

  @override
  int get hashCode => Object.hash(isAvailable, isEnabled);

  @override
  String toString() => 'NfcStatus('
      'isAvailable: $isAvailable, '
      'isEnabled: $isEnabled'
      ')';
}
