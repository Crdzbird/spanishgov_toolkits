part of 'dnie_error.dart';

/// {@template dnie_private_key_error}
/// Failed to extract the private key from the DNIe.
/// {@endtemplate}
final class DniePrivateKeyError extends DnieError {
  /// {@macro dnie_private_key_error}
  const factory DniePrivateKeyError() = DniePrivateKeyError._;

  const DniePrivateKeyError._()
    : super._('Failed to access the private key on the DNIe.');
}
