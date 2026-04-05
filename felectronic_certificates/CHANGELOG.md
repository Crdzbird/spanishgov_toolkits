# Changelog

## 1.0.0

- Import, list, select, sign, and delete PKCS#12 device certificates.
- CertificateSession builder for select-then-sign workflows.
- DeviceCertificateX extensions: isExpired, canSign, canAuthenticate, displayName, expiryStatus.
- CertKeyUsageLabel extension for human-readable usage names.
- Full X.509 parsing via parsed extension on DeviceCertificate.
- 6 signing algorithms: SHA-256/384/512 with RSA and ECDSA.
- Typed error hierarchy with 7 error subclasses.
- Android: CertificateSigner AAR + KeyChain API.
- iOS: Native Security.framework with Keychain access groups.
