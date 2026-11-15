# Changelog

## 1.0.1

- Raises the `pigeon` dev dependency to `^27.3.1`, so the package resolves and
  its bindings can be regenerated on Flutter 3.50. `pigeon` is only used to
  generate code; the published API and bindings are unchanged.

## 1.0.0

- Pigeon-based type-safe platform interface for device certificate management.
- List, select, import, sign, and delete PKCS#12 certificates.
- DeviceCertificate model with key usage flags and DER-encoded bytes.
- CertSignAlgorithm enum: SHA-256/384/512 with RSA and ECDSA.
- Typed error hierarchy with 7 error subclasses.
- DeviceCertificateX extensions for expiry status and usage queries.
- X.509 certificate parsing via parsed extension.
