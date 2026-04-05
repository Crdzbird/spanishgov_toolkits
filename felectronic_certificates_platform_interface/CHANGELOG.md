# Changelog

## 1.0.0

- Pigeon-based type-safe platform interface for device certificate management.
- List, select, import, sign, and delete PKCS#12 certificates.
- DeviceCertificate model with key usage flags and DER-encoded bytes.
- CertSignAlgorithm enum: SHA-256/384/512 with RSA and ECDSA.
- Typed error hierarchy with 7 error subclasses.
- DeviceCertificateX extensions for expiry status and usage queries.
- X.509 certificate parsing via parsed extension.
