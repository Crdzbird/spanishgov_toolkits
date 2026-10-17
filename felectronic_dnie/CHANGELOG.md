# Changelog

## 2.0.0

See "Migrating from 1.x" in the README for the changes in one place.

### Breaking changes

- `timeout` is a `Duration` on every operation, workflow and `DnieSession`.
- `probeAndSign` returns `SignedData` and throws `DnieNotDnieError` instead of
  returning `null` for a card that is not a DNIe.
- `stopSign()` and `DnieSession.stop()` end the stopped operation with
  `DnieCancelledError`; before, its future never completed.
- Requires the 2.0.0 platform interface and implementations; their breaking
  changes (`remainingRetries` is `int?`, `CertificateExpiryStatus.describe`,
  no `SignedData.fromMap`) apply here too.

### Added

- `DnieSession.signText`, the `.auth` and `.signing` copies, `withCertificate`,
  and `readFullIdentity()`, `checkReadiness()` and `probeAndSign()` as session
  methods.
- Re-exports the new shorthand: `isRetryable`, `isCredentialError`,
  `isLastAttempt`, `isValidNif`, `displayName`, `certificateKind` and more.

### Fixed

- Whitespace around the CAN and PIN is ignored by every entry point, not only
  by `DnieSession`.
- The platform setup the plugin needs is now documented in the README.
- Through the platform packages: Android reads a real DNIe and waits the full
  timeout, iOS links and builds under Swift Package Manager, and stopping an
  operation ends it on both.

## 1.0.0

- NFC card probe, PIN verification, data signing, and certificate reading.
- SIGN (FIRMA) and AUTH (AUTENTICACION) certificate type selection.
- Certificate details and personal data extraction.
- NFC hardware availability check.
- `DnieSession` builder for credential reuse across operations.
- Workflow functions: `checkReadiness`, `readFullIdentity`, `probeAndSign`.
- CAN and PIN validators with `DnieValidationError` enum.
- Model extensions: `CertificateInfoX`, `SignedDataX`, `NfcStatusX`, `PersonalDataX`.
- `NfcStatusType` and `CertificateExpiryStatus` enum-based status reporting.
- Full X.509 certificate parsing via `parsedCertificate` extension.
- Typed error hierarchy with 14 error subclasses including PIN retry count.
