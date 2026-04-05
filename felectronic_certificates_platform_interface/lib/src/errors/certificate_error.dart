// ignore_for_file: sort_constructors_first, factory must follow fields

import 'package:flutter/services.dart';

/// {@template certificate_error}
/// Sealed hierarchy of errors that can occur during device certificate
/// operations.
/// {@endtemplate}
sealed class CertificateError implements Exception {
  /// {@macro certificate_error}
  const CertificateError(this.message);

  /// Human-readable description of the error.
  final String message;

  /// Maps a [PlatformException] from the native side to a typed
  /// [CertificateError].
  ///
  /// The native plugins use consistent error codes across Android and iOS.
  factory CertificateError.fromPlatformException(PlatformException exception) {
    return switch (exception.code) {
      'NotSelectedCertificate' => const CertNotSelectedError(),
      'AddCertificateCanceled' => const CertImportCancelledError(),
      'IncorrectPassword' => const CertIncorrectPasswordError(),
      'CertificateInKeyChain' => const CertAlreadyExistsError(),
      'SigningError' => const CertSigningError(),
      'CertificateNotFound' => const CertNotFoundError(),
      _ => CertUnknownError(
          exception.message ?? 'Unknown error: ${exception.code}',
        ),
    };
  }

  @override
  String toString() => '${_typeName(this)}: $message';

  static String _typeName(CertificateError error) => switch (error) {
        CertNotSelectedError() => 'CertNotSelectedError',
        CertImportCancelledError() => 'CertImportCancelledError',
        CertIncorrectPasswordError() => 'CertIncorrectPasswordError',
        CertAlreadyExistsError() => 'CertAlreadyExistsError',
        CertSigningError() => 'CertSigningError',
        CertNotFoundError() => 'CertNotFoundError',
        CertUnknownError() => 'CertUnknownError',
      };
}

/// {@template cert_not_selected_error}
/// No default certificate has been selected.
/// {@endtemplate}
final class CertNotSelectedError extends CertificateError {
  /// {@macro cert_not_selected_error}
  const CertNotSelectedError()
      : super('No certificate is currently selected as default.');
}

/// {@template cert_import_cancelled_error}
/// The certificate import was cancelled by the user.
/// {@endtemplate}
final class CertImportCancelledError extends CertificateError {
  /// {@macro cert_import_cancelled_error}
  const CertImportCancelledError()
      : super('Certificate import was cancelled.');
}

/// {@template cert_incorrect_password_error}
/// The password for the PKCS#12 file was incorrect.
/// {@endtemplate}
final class CertIncorrectPasswordError extends CertificateError {
  /// {@macro cert_incorrect_password_error}
  const CertIncorrectPasswordError()
      : super('Incorrect password for the certificate file.');
}

/// {@template cert_already_exists_error}
/// A certificate with the same identity already exists in the keychain.
/// {@endtemplate}
final class CertAlreadyExistsError extends CertificateError {
  /// {@macro cert_already_exists_error}
  const CertAlreadyExistsError()
      : super('Certificate already exists in the keychain.');
}

/// {@template cert_signing_error}
/// The signing operation failed.
/// {@endtemplate}
final class CertSigningError extends CertificateError {
  /// {@macro cert_signing_error}
  const CertSigningError()
      : super('Failed to sign data with the certificate.');
}

/// {@template cert_not_found_error}
/// The requested certificate was not found.
/// {@endtemplate}
final class CertNotFoundError extends CertificateError {
  /// {@macro cert_not_found_error}
  const CertNotFoundError()
      : super('Certificate not found.');
}

/// {@template cert_unknown_error}
/// An unexpected error occurred.
/// {@endtemplate}
final class CertUnknownError extends CertificateError {
  /// {@macro cert_unknown_error}
  const CertUnknownError(super.message);
}
