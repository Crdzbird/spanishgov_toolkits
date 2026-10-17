part of 'dnie_error.dart';

/// {@template dnie_wrong_pin_error}
/// The PIN entered was incorrect.
/// {@endtemplate}
final class DnieWrongPinError extends DnieError {
  /// {@macro dnie_wrong_pin_error}
  const factory DnieWrongPinError({required int remainingRetries}) =
      DnieWrongPinError._;

  const DnieWrongPinError._({required this.remainingRetries})
    : super._('Wrong PIN entered.');

  /// Number of PIN attempts remaining before the card locks.
  /// A value of `-1` means the count is unknown.
  final int remainingRetries;

  @override
  String toString() =>
      'DnieWrongPinError: $message '
      '($remainingRetries retries remaining)';
}
