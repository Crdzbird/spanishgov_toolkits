part of 'dnie_error.dart';

String _typeName(DnieError error) => switch (error) {
  DnieTimeoutError() => 'DnieTimeoutError',
  DnieCancelledError() => 'DnieCancelledError',
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
