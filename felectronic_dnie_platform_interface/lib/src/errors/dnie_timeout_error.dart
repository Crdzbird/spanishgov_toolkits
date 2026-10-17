part of 'dnie_error.dart';

/// {@template dnie_timeout_error}
/// NFC card detection timed out.
/// {@endtemplate}
final class DnieTimeoutError extends DnieError {
  /// {@macro dnie_timeout_error}
  const factory DnieTimeoutError() = DnieTimeoutError._;

  const DnieTimeoutError._()
    : super._(
        'DNIe card detection timed out. '
        'Please hold your device near the card.',
      );
}
