/// {@template clave_error}
/// Sealed hierarchy of errors that can occur during Cl@ve authentication.
/// {@endtemplate}
sealed class ClaveError implements Exception {
  /// {@macro clave_error}
  const ClaveError(this.message);

  /// Human-readable description of the error.
  final String message;

  @override
  String toString() => message;
}

/// {@template clave_auth_cancelled_error}
/// The user cancelled the authentication flow.
/// {@endtemplate}
final class ClaveAuthCancelledError extends ClaveError {
  /// {@macro clave_auth_cancelled_error}
  const ClaveAuthCancelledError()
      : super('Authentication was cancelled by the user.');
}

/// {@template clave_invalid_contrast_error}
/// The contrast data (validity date or support number) is incorrect.
/// {@endtemplate}
final class ClaveInvalidContrastError extends ClaveError {
  /// {@macro clave_invalid_contrast_error}
  const ClaveInvalidContrastError()
      : super('The contrast data provided does not match the document.');
}

/// {@template clave_request_already_sent_error}
/// A Cl@ve Movil notification is already pending for this document.
/// {@endtemplate}
final class ClaveRequestAlreadySentError extends ClaveError {
  /// {@macro clave_request_already_sent_error}
  const ClaveRequestAlreadySentError()
      : super('A notification request has already been sent. '
            'Please wait or reject the previous one.');
}

/// {@template clave_session_expired_error}
/// The Cl@ve Movil session or token has expired.
/// {@endtemplate}
final class ClaveSessionExpiredError extends ClaveError {
  /// {@macro clave_session_expired_error}
  const ClaveSessionExpiredError()
      : super('The session has expired. Please start a new request.');
}

/// {@template clave_refused_error}
/// The authentication request was refused (e.g. wrong credentials).
/// {@endtemplate}
final class ClaveRefusedError extends ClaveError {
  /// {@macro clave_refused_error}
  const ClaveRefusedError()
      : super('Authentication was refused.');
}

/// {@template clave_discovery_failed_error}
/// Failed to reach the OpenID Connect discovery endpoint.
/// {@endtemplate}
final class ClaveDiscoveryFailedError extends ClaveError {
  /// {@macro clave_discovery_failed_error}
  const ClaveDiscoveryFailedError()
      : super('Could not reach the identity provider. '
            'Check your network connection.');
}

/// {@template clave_idle_error}
/// The Cl@ve Movil validation is still pending (user hasn't confirmed yet).
///
/// This is not a terminal error — the caller should keep polling.
/// {@endtemplate}
final class ClaveIdleError extends ClaveError {
  /// {@macro clave_idle_error}
  const ClaveIdleError()
      : super('Waiting for user confirmation on the Cl@ve app.');
}

/// {@template clave_unknown_error}
/// An unexpected error occurred.
/// {@endtemplate}
final class ClaveUnknownError extends ClaveError {
  /// {@macro clave_unknown_error}
  const ClaveUnknownError(super.message);
}
