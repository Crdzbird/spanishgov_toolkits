part of 'dnie_error.dart';

/// {@template dnie_cancelled_error}
/// The operation was cancelled before it finished, either by a call to stop
/// it or by the user dismissing the system NFC sheet.
/// {@endtemplate}
final class DnieCancelledError extends DnieError {
  /// {@macro dnie_cancelled_error}
  const factory DnieCancelledError() = DnieCancelledError._;

  const DnieCancelledError._() : super._('The NFC operation was cancelled.');
}
