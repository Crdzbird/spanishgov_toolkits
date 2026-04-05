// ignore_for_file: sort_constructors_first, factory must follow fields

import 'package:flutter/services.dart';

/// {@template dnie_error}
/// Sealed hierarchy of errors that can occur during DNIe NFC operations.
/// {@endtemplate}
sealed class DnieError implements Exception {
  /// {@macro dnie_error}
  const DnieError(this.message);

  /// Human-readable description of the error.
  final String message;

  /// Maps a [PlatformException] from the native side to a typed [DnieError].
  ///
  /// The native plugins use consistent error codes across Android and iOS.
  factory DnieError.fromPlatformException(PlatformException exception) {
    return switch (exception.code) {
      'DSTimeoutException' => const DnieTimeoutError(),
      'DSCardTagException' => const DnieCardTagError(),
      'DSDNIeProviderException' => const DnieProviderError(),
      'DSUnderageDocumentException' => const DnieUnderageError(),
      'DSExpiredCertificateException' => const DnieExpiredCertificateError(),
      'DSDNIeConnectionException' => const DnieConnectionError(),
      'DSPrivateKeyException' => const DniePrivateKeyError(),
      'DSSigningException' => const DnieSigningError(),
      'DSDNIeWrongPINException' => DnieWrongPinError(
          remainingRetries: _parseRetries(exception.message),
        ),
      'DSDNIeWrongCANException' => const DnieWrongCanError(),
      'DSDNIeLockedPINException' => const DnieLockedPinError(),
      'DSNotDNIeException' => const DnieNotDnieError(),
      'DSDNIeDamagedException' => const DnieDamagedError(),
      _ => DnieUnknownError(
          exception.message ?? 'Unknown error: ${exception.code}',
        ),
    };
  }

  static int _parseRetries(String? message) {
    if (message == null) return -1;
    final match = RegExp(r'(\d+)').firstMatch(message);
    if (match == null) return -1;
    try {
      return int.parse(match.group(1)!);
    } on FormatException {
      return -1;
    }
  }

  @override
  String toString() => '${_typeName(this)}: $message';

  static String _typeName(DnieError error) => switch (error) {
        DnieTimeoutError() => 'DnieTimeoutError',
        DnieCardTagError() => 'DnieCardTagError',
        DnieProviderError() => 'DnieProviderError',
        DnieUnderageError() => 'DnieUnderageError',
        DnieExpiredCertificateError() => 'DnieExpiredCertificateError',
        DnieConnectionError() => 'DnieConnectionError',
        DniePrivateKeyError() => 'DniePrivateKeyError',
        DnieSigningError() => 'DnieSigningError',
        DnieWrongPinError() => 'DnieWrongPinError',
        DnieWrongCanError() => 'DnieWrongCanError',
        DnieLockedPinError() => 'DnieLockedPinError',
        DnieNotDnieError() => 'DnieNotDnieError',
        DnieDamagedError() => 'DnieDamagedError',
        DnieUnknownError() => 'DnieUnknownError',
      };
}

/// {@template dnie_timeout_error}
/// NFC card detection timed out.
/// {@endtemplate}
final class DnieTimeoutError extends DnieError {
  /// {@macro dnie_timeout_error}
  const DnieTimeoutError()
      : super('DNIe card detection timed out. '
            'Please hold your device near the card.');
}

/// {@template dnie_card_tag_error}
/// Could not read the NFC tag from the card.
/// {@endtemplate}
final class DnieCardTagError extends DnieError {
  /// {@macro dnie_card_tag_error}
  const DnieCardTagError()
      : super('Could not get NFC tag from the card. '
            'Please try again.');
}

/// {@template dnie_provider_error}
/// Failed to create the DNIe cryptographic provider.
/// {@endtemplate}
final class DnieProviderError extends DnieError {
  /// {@macro dnie_provider_error}
  const DnieProviderError()
      : super('Failed to create DNIe provider. '
            'The card may not be a valid DNIe.');
}

/// {@template dnie_underage_error}
/// The document belongs to an underage user whose certificate
/// cannot be used for signing.
/// {@endtemplate}
final class DnieUnderageError extends DnieError {
  /// {@macro dnie_underage_error}
  const DnieUnderageError()
      : super('Document belongs to an underage user. '
            'Signing certificates are not available.');
}

/// {@template dnie_expired_certificate_error}
/// The certificate on the DNIe has expired.
/// {@endtemplate}
final class DnieExpiredCertificateError extends DnieError {
  /// {@macro dnie_expired_certificate_error}
  const DnieExpiredCertificateError()
      : super('The DNIe certificate has expired. '
            'Please renew your DNIe.');
}

/// {@template dnie_connection_error}
/// NFC connection to the DNIe was lost or could not be established.
/// {@endtemplate}
final class DnieConnectionError extends DnieError {
  /// {@macro dnie_connection_error}
  const DnieConnectionError()
      : super('Failed to establish NFC connection with DNIe. '
            'Please hold the card steady.');
}

/// {@template dnie_private_key_error}
/// Failed to extract the private key from the DNIe.
/// {@endtemplate}
final class DniePrivateKeyError extends DnieError {
  /// {@macro dnie_private_key_error}
  const DniePrivateKeyError()
      : super('Failed to access the private key on the DNIe.');
}

/// {@template dnie_signing_error}
/// The signing operation itself failed.
/// {@endtemplate}
final class DnieSigningError extends DnieError {
  /// {@macro dnie_signing_error}
  const DnieSigningError()
      : super('Failed to sign data with the DNIe.');
}

/// {@template dnie_wrong_pin_error}
/// The PIN entered was incorrect.
/// {@endtemplate}
final class DnieWrongPinError extends DnieError {
  /// {@macro dnie_wrong_pin_error}
  const DnieWrongPinError({required this.remainingRetries})
      : super('Wrong PIN entered.');

  /// Number of PIN attempts remaining before the card locks.
  /// A value of `-1` means the count is unknown.
  final int remainingRetries;

  @override
  String toString() =>
      'DnieWrongPinError: $message '
      '($remainingRetries retries remaining)';
}

/// {@template dnie_wrong_can_error}
/// The CAN (Card Access Number) entered was incorrect.
/// {@endtemplate}
final class DnieWrongCanError extends DnieError {
  /// {@macro dnie_wrong_can_error}
  const DnieWrongCanError() : super('Wrong CAN entered.');
}

/// {@template dnie_locked_pin_error}
/// The PIN has been locked due to too many failed attempts.
/// {@endtemplate}
final class DnieLockedPinError extends DnieError {
  /// {@macro dnie_locked_pin_error}
  const DnieLockedPinError()
      : super('DNIe locked. Too many incorrect PIN attempts.');
}

/// {@template dnie_not_dnie_error}
/// The NFC card is not a DNIe.
/// {@endtemplate}
final class DnieNotDnieError extends DnieError {
  /// {@macro dnie_not_dnie_error}
  const DnieNotDnieError()
      : super('The card is not a Spanish electronic DNIe.');
}

/// {@template dnie_damaged_error}
/// The DNIe is physically damaged or burned.
/// {@endtemplate}
final class DnieDamagedError extends DnieError {
  /// {@macro dnie_damaged_error}
  const DnieDamagedError()
      : super('The DNIe appears to be damaged.');
}

/// {@template dnie_unknown_error}
/// An unexpected error occurred.
/// {@endtemplate}
final class DnieUnknownError extends DnieError {
  /// {@macro dnie_unknown_error}
  const DnieUnknownError(super.message);
}
