part of 'dnie_error.dart';

/// {@template dnie_locked_pin_error}
/// The PIN has been locked due to too many failed attempts.
/// {@endtemplate}
final class DnieLockedPinError extends DnieError {
  /// {@macro dnie_locked_pin_error}
  const factory DnieLockedPinError() = DnieLockedPinError._;

  const DnieLockedPinError._()
    : super._('DNIe locked. Too many incorrect PIN attempts.');
}
