part of 'dnie_error.dart';

/// {@template dnie_connection_error}
/// NFC connection to the DNIe was lost or could not be established.
/// {@endtemplate}
final class DnieConnectionError extends DnieError {
  /// {@macro dnie_connection_error}
  const factory DnieConnectionError() = DnieConnectionError._;

  const DnieConnectionError._()
    : super._(
        'Failed to establish NFC connection with DNIe. '
        'Please hold the card steady.',
      );
}
