part of 'dnie_error.dart';

/// {@template dnie_unsupported_error}
/// The operation is not available on this platform.
/// {@endtemplate}
final class DnieUnsupportedError extends DnieError {
  /// {@macro dnie_unsupported_error}
  const factory DnieUnsupportedError([String? message]) =
      DnieUnsupportedError._;

  const DnieUnsupportedError._([String? message])
    : super._(message ?? 'This operation is not available on this platform.');
}
