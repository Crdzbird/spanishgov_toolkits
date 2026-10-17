part of 'dnie_error.dart';

/// {@template dnie_wrong_pin_error}
/// The PIN entered was incorrect.
/// {@endtemplate}
final class DnieWrongPinError extends DnieError {
  /// {@macro dnie_wrong_pin_error}
  const factory DnieWrongPinError({int? remainingRetries}) =
      DnieWrongPinError._;

  const DnieWrongPinError._({this.remainingRetries})
    : super._('Wrong PIN entered.');

  /// Number of PIN attempts remaining before the card locks, or `null` when
  /// the card did not say.
  final int? remainingRetries;

  @override
  String toString() =>
      'DnieWrongPinError: $message '
      '(${remainingRetries ?? 'unknown'} retries remaining)';
}
