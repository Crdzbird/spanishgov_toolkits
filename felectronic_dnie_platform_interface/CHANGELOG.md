# Changelog

## 3.0.0

### Breaking changes

- `sign` is defined as signing on the device: the raw PKCS#1 v1.5 signature,
  SHA-512 with RSA, and the certificate as standard Base64 DER, with no network
  call. Both implementations now do this.
- New abstract method `signCades` on `FelectronicDniePlatform`, and a matching
  `signCades` on the Pigeon host API, for CAdES through the remote three-phase
  service. Custom platforms must implement it.
- `DnieNfcUnavailableError` (code `DSNfcUnavailableException`) and
  `DnieUnsupportedError` (code `DSUnsupportedException`) join the sealed
  `DnieError`, so exhaustive switches need two more cases.

## 2.0.0

### Breaking changes

- Every operation takes `timeout` as a `Duration`, defaulting to the new
  `dnieDefaultTimeout` (30 seconds). The unit used to live only in the docs.
- `stopSign()` must now end the stopped operation with `DnieCancelledError`.
- `DnieWrongPinError.remainingRetries` is `int?`: `null` when the card does not
  say, instead of `-1`.
- `CertificateExpiryStatus` is a plain enum; `message` and `withDays()` are
  replaced by `describe(daysLeft)`.
- `SignedData.fromMap` and `SignedData.fromJson` are removed. They predate the
  Pigeon bindings and had no callers.
- Models and errors are `final` classes, with `const factory` constructors.

### Added

- `DnieCancelledError`, for a stopped operation and for the user dismissing the
  iOS NFC sheet (which used to arrive as `DnieUnknownError`).
- `DnieErrorX.isRetryable` and `isCredentialError`, and
  `DnieWrongPinErrorX.isLastAttempt`.
- `String.isValidNif`, which checks a NIF or NIE control letter.
- `PersonalData.certificateKind` and `displayName`;
  `DnieCertificateType.fromValue`; `CertificateInfo.isValidAt` and `remaining`;
  `SignedData.certificateDer`.
- `MethodChannelFelectronicDnie` is exported, so platform implementations can
  extend it.

### Fixed

- `PersonalData.isAuthCert` was never true for a real card, which writes
  "AUTENTICACIÓN" with an accent.
- `CertificateInfo.isValidForSigning` follows one rule, `isValidAt(now)`.

## 1.0.0

- Pigeon-based type-safe platform interface for DNIe NFC operations.
- Sign data with SIGN or AUTH certificate selection.
- Read raw certificate, certificate details, and personal data.
- Card probe (no PIN required) with ATR and tag ID.
- PIN verification without signing.
- NFC hardware availability check.
- Typed error hierarchy with 14 error subclasses.
- Input validators for CAN and PIN with enum-based error codes.
- Model extensions for certificate expiry, NFC status, and signed data.
- X.509 certificate parsing via felectronic_x509 integration.
