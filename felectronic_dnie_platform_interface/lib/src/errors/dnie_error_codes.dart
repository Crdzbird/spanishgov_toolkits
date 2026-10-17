part of 'dnie_error.dart';

DnieError _fromPlatformException(PlatformException exception) =>
    switch (exception.code) {
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

int? _parseRetries(String? message) {
  final digits = RegExp(r'\d+').firstMatch(message ?? '')?.group(0);
  return digits == null ? null : int.tryParse(digits);
}
