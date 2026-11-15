part of 'dnie_error.dart';

/// {@template dnie_nfc_unavailable_error}
/// The device has no NFC reader, or NFC is switched off.
/// {@endtemplate}
final class DnieNfcUnavailableError extends DnieError {
  /// {@macro dnie_nfc_unavailable_error}
  const factory DnieNfcUnavailableError() = DnieNfcUnavailableError._;

  const DnieNfcUnavailableError._()
    : super._('NFC is not available. Switch NFC on and try again.');
}
