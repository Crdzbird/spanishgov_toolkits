# Changelog

## 1.1.0

- Requires Flutter 3.47 and Dart 3.13. The certificate picker imports Material
  from `material_ui`, since Flutter deprecated `package:flutter/material.dart`
  after 3.47.
- `AppleCertificates.isSupported`, and the certificate picker's empty-list
  message, read `defaultTargetPlatform` instead of `dart:io`'s `Platform`. The
  answer on a device is the same, but it is false on the web rather than an
  exception, and tests can set the platform instead of inheriting the host's.
- `CertificateSession.sign` and `signWithDefaultCertificate` accept an optional
  `format`, producing CAdES, PAdES or XAdES signatures through the @firma
  service. Without one, behavior is unchanged: a bare PKCS#1 signature computed
  on device, with nothing transmitted.
- Requesting a format sends the document to the signing service; the private
  key still never leaves the device.
- `transport` is required alongside `format`, leaving timeouts, proxying and
  certificate pinning with the caller.
- Every `CertSignAlgorithm`, including SHA-384 and the ECDSA variants, maps to
  the service's algorithm names.

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
