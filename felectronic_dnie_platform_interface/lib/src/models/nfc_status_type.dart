/// {@template nfc_status_type}
/// The current state of the device's NFC hardware.
/// {@endtemplate}
enum NfcStatusType {
  /// NFC hardware is available and enabled.
  ready('NFC is ready.'),

  /// The device does not have NFC hardware.
  unavailable('This device does not have NFC.'),

  /// NFC hardware exists but is disabled in system settings.
  disabled('NFC is disabled. Enable it in Settings.');

  /// {@macro nfc_status_type}
  const NfcStatusType(this.message);

  /// Human-readable status message.
  final String message;

  @override
  String toString() => message;
}
