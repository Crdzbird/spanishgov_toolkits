# felectronic_certificates

Flutter plugin for managing device-stored certificates. Import, sign with, list, and delete PKCS#12 certificates using the Android KeyStore or iOS Keychain.

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

## Features

| Feature | Description |
|---------|-------------|
| **Import** | Import PKCS#12 (.p12/.pfx) files into the device keystore |
| **Sign** | Sign arbitrary data with a certificate's private key |
| **List** | Retrieve all installed certificates with metadata |
| **Select** | Open a native certificate picker or set default by serial |
| **Delete** | Remove certificates by serial number or default selection |
| **Session** | Builder pattern for repeated operations on one certificate |
| **Extensions** | Expiry checks, usage labels, display helpers |

## Platform Support

| Android | iOS |
|:-------:|:---:|
| API 28+ | iOS 13+ |

## Installation

```yaml
dependencies:
  felectronic_certificates: ^0.1.0
```

### Android Setup

This plugin depends on a bundled AAR (`certificatesigner-release.aar`) for certificate operations. Add the certificate-signer module to your app's `settings.gradle.kts`:

```kotlin
// android/settings.gradle.kts
include(":certificate-signer")
project(":certificate-signer").projectDir =
    file("../path-to/felectronic_certificates_android/android/certificate-signer")
```

The plugin's `build.gradle.kts` will automatically link the AAR when the `:certificate-signer` project is found.

### iOS Setup

No additional setup required. The plugin uses the iOS Keychain APIs directly.

## Usage

```dart
import 'package:felectronic_certificates/felectronic_certificates.dart';
```

### Import a PKCS#12 Certificate

```dart
import 'dart:io';

final bytes = await File('certificate.p12').readAsBytes();
await importCertificate(
  bytes,
  password: 'cert-password',
  alias: 'My Work Certificate',
);
```

### List All Certificates

```dart
final certs = await getAllCertificates();
for (final cert in certs) {
  print('${cert.displayName} - ${cert.expiryStatus}');
  print('  Serial: ${cert.serialNumber}');
  print('  Issuer: ${cert.issuerName}');
  print('  Usages: ${cert.usageSummary}');
  print('  Expired: ${cert.isExpired}');
}
```

### Select a Default Certificate

```dart
// Open the native picker
final selected = await selectDefaultCertificate();
if (selected != null) {
  print('Selected: ${selected.holderName}');
}

// Or set by serial number directly
await setDefaultCertificateBySerialNumber('AB12CD34');

// Get the current default
final current = await getDefaultCertificate();

// Clear the default selection
await clearDefaultCertificate();
```

### Sign Data

```dart
import 'dart:convert';
import 'dart:typed_data';

final data = Uint8List.fromList(utf8.encode('Data to sign'));

// Sign with the default certificate (SHA-256 with RSA)
final signature = await signWithDefaultCertificate(data);

// Sign with a different algorithm
final ecSignature = await signWithDefaultCertificate(
  data,
  algorithm: CertSignAlgorithm.sha256ec,
);
```

### Delete a Certificate

```dart
// Delete the current default
await deleteDefaultCertificate();

// Delete by serial number
await deleteCertificateBySerialNumber('AB12CD34');
```

## CertificateSession

`CertificateSession` wraps a selected certificate for repeated operations without re-selecting each time:

```dart
// From the native picker
final session = await CertificateSession.select();
if (session != null) {
  print('Using: ${session.certificate.holderName}');

  final signature = await session.sign(myData);

  // Clear default selection (does not delete the cert)
  await session.clear();

  // Or delete the certificate entirely
  await session.delete();
}

// From the existing default
final session = await CertificateSession.fromDefault();
```

## Signing Algorithms

| Enum | Algorithm |
|------|-----------|
| `CertSignAlgorithm.sha256rsa` | SHA-256 with RSA (default) |
| `CertSignAlgorithm.sha384rsa` | SHA-384 with RSA |
| `CertSignAlgorithm.sha512rsa` | SHA-512 with RSA |
| `CertSignAlgorithm.sha256ec` | SHA-256 with ECDSA |
| `CertSignAlgorithm.sha384ec` | SHA-384 with ECDSA |
| `CertSignAlgorithm.sha512ec` | SHA-512 with ECDSA |

## Key Usage Types

| Enum | Description |
|------|-------------|
| `CertKeyUsage.signing` | Digital signatures |
| `CertKeyUsage.authentication` | Identity authentication |
| `CertKeyUsage.encryption` | Data encryption |

Parse from strings:

```dart
final usage = CertKeyUsage.tryParse('SIGNING');
final usages = CertKeyUsage.parseUsages('SIGNING;AUTHENTICATION');
```

## DeviceCertificate Extensions

The `DeviceCertificateX` extension adds convenience properties:

```dart
cert.isExpired;       // Whether the certificate has expired
cert.daysUntilExpiry; // Days remaining (negative if expired)
cert.isExpiringSoon;  // Expires within 30 days
cert.canSign;         // Has CertKeyUsage.signing
cert.canAuthenticate; // Has CertKeyUsage.authentication
cert.canEncrypt;      // Has CertKeyUsage.encryption
cert.usageSummary;    // "Signing, Authentication"
cert.displayName;     // Alias if set, otherwise holderName
cert.expiryStatus;    // "Expires in 45 days", "Expired", etc.
```

## Error Handling

All errors extend the sealed `CertificateError` class:

| Error | Description |
|-------|-------------|
| `CertNotSelectedError` | No default certificate is selected |
| `CertImportCancelledError` | User cancelled the import |
| `CertIncorrectPasswordError` | Wrong password for the PKCS#12 file |
| `CertAlreadyExistsError` | Certificate already exists in the keychain |
| `CertSigningError` | Signing operation failed |
| `CertNotFoundError` | Certificate not found |
| `CertUnknownError` | Unexpected error with a message |

```dart
try {
  await signWithDefaultCertificate(data);
} on CertNotSelectedError {
  print('Please select a certificate first');
} on CertSigningError {
  print('Signing failed');
} on CertificateError catch (e) {
  print('Certificate error: ${e.message}');
}
```

## Architecture

This is a federated Flutter plugin:

| Package | Description |
|---------|-------------|
| `felectronic_certificates` | App-facing API |
| `felectronic_certificates_platform_interface` | Platform interface + models |
| `felectronic_certificates_android` | Android implementation (KeyStore + AAR) |
| `felectronic_certificates_ios` | iOS implementation (Keychain) |

Platform communication uses [Pigeon](https://pub.dev/packages/pigeon) for type-safe bindings.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
