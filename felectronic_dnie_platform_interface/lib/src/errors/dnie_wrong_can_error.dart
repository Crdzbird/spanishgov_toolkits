part of 'dnie_error.dart';

/// {@template dnie_wrong_can_error}
/// The CAN (Card Access Number) entered was incorrect.
/// {@endtemplate}
final class DnieWrongCanError extends DnieError {
  /// {@macro dnie_wrong_can_error}
  const factory DnieWrongCanError() = DnieWrongCanError._;

  const DnieWrongCanError._() : super._('Wrong CAN entered.');
}
