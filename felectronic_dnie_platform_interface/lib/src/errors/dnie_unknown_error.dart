part of 'dnie_error.dart';

/// {@template dnie_unknown_error}
/// An unexpected error occurred.
/// {@endtemplate}
final class DnieUnknownError extends DnieError {
  /// {@macro dnie_unknown_error}
  const factory DnieUnknownError(String message) = DnieUnknownError._;

  const DnieUnknownError._(super.message) : super._();
}
