part of 'dnie_error.dart';

/// {@template dnie_signing_error}
/// The signing operation itself failed.
/// {@endtemplate}
final class DnieSigningError extends DnieError {
  /// {@macro dnie_signing_error}
  const factory DnieSigningError() = DnieSigningError._;

  const DnieSigningError._() : super._('Failed to sign data with the DNIe.');
}
