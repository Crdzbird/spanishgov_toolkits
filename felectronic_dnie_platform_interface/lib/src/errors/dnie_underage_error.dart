part of 'dnie_error.dart';

/// {@template dnie_underage_error}
/// The document belongs to an underage user whose certificate
/// cannot be used for signing.
/// {@endtemplate}
final class DnieUnderageError extends DnieError {
  /// {@macro dnie_underage_error}
  const factory DnieUnderageError() = DnieUnderageError._;

  const DnieUnderageError._()
    : super._(
        'Document belongs to an underage user. '
        'Signing certificates are not available.',
      );
}
