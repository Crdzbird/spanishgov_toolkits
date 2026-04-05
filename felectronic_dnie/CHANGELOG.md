# Changelog

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
