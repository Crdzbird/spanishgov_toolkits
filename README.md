# felectronic_dnie

A Flutter plugin for reading and signing with the Spanish electronic DNIe (Documento Nacional de Identidad electronico) via NFC.

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

## Features

| Feature | Description | Requires PIN |
|---------|------------|:---:|
| **NFC Availability** | Check if device has NFC and if it's enabled | No |
| **Probe Card** | Detect if an NFC card is a valid DNIe | No |
| **Verify PIN** | Validate CAN + PIN without signing | Yes |
| **Sign Data** | Sign arbitrary data with the DNIe private key | Yes |
| **Read Certificate** | Read the raw signing or auth certificate | Yes |
| **Certificate Details** | Parse X.509 certificate fields (subject, issuer, validity) | Yes |
| **Personal Data** | Extract name, NIF, country from the certificate | Yes |
| **Stop Scan** | Cancel an in-progress NFC operation | No |

### Certificate Types

The Spanish DNIe contains **two certificates**:

| Type | Enum | Use Case |
|------|------|----------|
| **FIRMA** (Signing) | `DnieCertificateType.sign` | Non-repudiation digital signatures |
| **AUTENTICACION** (Auth) | `DnieCertificateType.auth` | Identity authentication (Cl@ve, Sede Electronica) |

All certificate-dependent operations accept a `certificateType` parameter (defaults to `.sign`).

## Platform Support

| Android | iOS |
|:-------:|:---:|
| API 24+ | iOS 13+ |

## Installation

```yaml
dependencies:
  felectronic_dnie: ^1.0.0
```

### iOS Setup

Add NFC capabilities to your iOS project:

1. Enable **Near Field Communication Tag Reading** in your target's Signing & Capabilities.
2. Add to `Info.plist`:

```xml
<key>NFCReaderUsageDescription</key>
<string>This app uses NFC to read your DNIe card.</string>
<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
<array>
  <string>A0000000049900</string>
</array>
```

### Android Setup

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.NFC" />
<uses-feature android:name="android.hardware.nfc" android:required="true" />
```

## Usage

```dart
import 'package:felectronic_dnie/felectronic_dnie.dart';
```

### Check NFC Availability

Check if NFC is available before showing NFC-related UI:

```dart
final nfc = await checkNfcAvailability();
if (!nfc.isAvailable) {
  print('This device does not have NFC.');
} else if (!nfc.isEnabled) {
  print('NFC is disabled. Enable it in Settings.');
}
```

### Probe Card (No PIN Required)

Check if an NFC card is a valid Spanish DNIe before asking for credentials:

```dart
final probe = await probeCard();
if (probe.isValidDnie) {
  print('Valid DNIe detected! Tag ID: ${probe.tagId}');
} else {
  print('Not a DNIe. ATR: ${probe.atrHex}');
}
```

### Verify PIN

Validate the user's CAN and PIN without performing any signing:

```dart
try {
  await verifyPin(can: '123456', pin: 'mySecurePin');
  print('Credentials are valid!');
} on DnieWrongPinError catch (e) {
  print('Wrong PIN. ${e.remainingRetries} retries remaining.');
} on DnieWrongCanError {
  print('Wrong CAN.');
}
```

### Sign Data

```dart
import 'dart:convert';

// Sign with the FIRMA certificate (default)
final result = await sign(
  data: utf8.encode('Hello, DNIe!'),
  can: '123456',
  pin: 'mySecurePin',
);

// Sign with the AUTH certificate
final authResult = await sign(
  data: utf8.encode('Auth challenge'),
  can: '123456',
  pin: 'mySecurePin',
  certificateType: DnieCertificateType.auth,
);
```

### Read Certificate

Read the raw certificate (SIGN or AUTH):

```dart
// Read the SIGN certificate
final signCert = await readCertificate(can: '123456', pin: 'mySecurePin');

// Read the AUTH certificate
final authCert = await readCertificate(
  can: '123456',
  pin: 'mySecurePin',
  certificateType: DnieCertificateType.auth,
);
```

### Certificate Details

Parse X.509 certificate metadata:

```dart
final info = await readCertificateDetails(
  can: '123456',
  pin: 'mySecurePin',
  certificateType: DnieCertificateType.auth,
);
print('Subject: ${info.subjectCommonName}');
print('NIF: ${info.subjectSerialNumber}');
print('Issuer: ${info.issuerCommonName} (${info.issuerOrganization})');
print('Valid: ${info.notValidBefore} - ${info.notValidAfter}');
print('Currently valid: ${info.isCurrentlyValid}');
```

### Personal Data

Extract identity information from the certificate subject:

```dart
final data = await readPersonalData(can: '123456', pin: 'mySecurePin');
print('Name: ${data.fullName}');
print('NIF: ${data.nif}');
print('Country: ${data.country}');
print('Type: ${data.certificateType}'); // FIRMA or AUTENTICACION
```

### Stop Scan

Cancel an in-progress NFC operation:

```dart
await stopSign();
```

## Error Handling

All operations throw typed [DnieError] subclasses:

| Error | Description |
|-------|------------|
| `DnieTimeoutError` | NFC scan timed out |
| `DnieWrongPinError` | Incorrect PIN (check `remainingRetries`) |
| `DnieWrongCanError` | Incorrect CAN |
| `DnieLockedPinError` | PIN locked after too many attempts |
| `DnieNotDnieError` | Card is not a DNIe |
| `DnieDamagedError` | Card is physically damaged |
| `DnieExpiredCertificateError` | Certificate has expired |
| `DnieUnderageError` | Underage document, signing not available |
| `DnieConnectionError` | NFC connection lost |
| `DnieProviderError` | Failed to create cryptographic provider |
| `DniePrivateKeyError` | Failed to access private key |
| `DnieSigningError` | Signing operation failed |
| `DnieCardTagError` | Could not read NFC tag |

```dart
try {
  await sign(data: myData, can: myCan, pin: myPin);
} on DnieWrongPinError catch (e) {
  print('Wrong PIN. ${e.remainingRetries} retries remaining.');
} on DnieLockedPinError {
  print('Card is locked!');
} on DnieError catch (e) {
  print('DNIe error: ${e.message}');
}
```

## Architecture

This is a federated Flutter plugin with the following packages:

| Package | Description |
|---------|------------|
| [`felectronic_dnie`](felectronic_dnie/) | App-facing API |
| [`felectronic_dnie_platform_interface`](felectronic_dnie_platform_interface/) | Platform interface |
| [`felectronic_dnie_android`](felectronic_dnie_android/) | Android implementation |
| [`felectronic_dnie_ios`](felectronic_dnie_ios/) | iOS implementation |

Platform communication uses [Pigeon](https://pub.dev/packages/pigeon) for type-safe bindings.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
