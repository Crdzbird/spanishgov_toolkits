part of 'dnie_error.dart';

/// {@template dnie_not_dnie_error}
/// The NFC card is not a DNIe.
/// {@endtemplate}
final class DnieNotDnieError extends DnieError {
  /// {@macro dnie_not_dnie_error}
  const factory DnieNotDnieError() = DnieNotDnieError._;

  const DnieNotDnieError._()
    : super._('The card is not a Spanish electronic DNIe.');
}
