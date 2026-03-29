# felectronic_dnie

A Flutter plugin for reading and signing with the Spanish electronic DNIe (Documento Nacional de Identidad electronico) via NFC.

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

## Features

- **NFC Availability** - Check if NFC hardware is available and enabled
- **Probe Card** - Detect if an NFC card is a valid DNIe (no PIN required)
- **Verify PIN** - Validate CAN + PIN credentials without signing
- **Sign Data** - Sign arbitrary bytes with the DNIe private key
- **Read Certificate** - Read the raw signing or authentication certificate
- **Certificate Details** - Parse X.509 subject, issuer, validity, and serial
- **Personal Data** - Extract name, NIF, country from the certificate
- **Certificate Type Selection** - Choose between SIGN (FIRMA) and AUTH (AUTENTICACION)

## Usage

```dart
import 'package:felectronic_dnie/felectronic_dnie.dart';

// Check NFC availability
final nfc = await checkNfcAvailability();
if (!nfc.isEnabled) print('NFC is not available');

// Probe card (no PIN required)
final probe = await probeCard();
print('Valid DNIe: ${probe.isValidDnie}');

// Verify credentials
await verifyPin(can: '123456', pin: 'mySecurePin');

// Sign with SIGN certificate (default)
final signed = await sign(
  data: utf8.encode('Hello, DNIe!'),
  can: '123456',
  pin: 'mySecurePin',
);

// Read AUTH certificate for identity authentication
final authCert = await readCertificate(
  can: '123456',
  pin: 'mySecurePin',
  certificateType: DnieCertificateType.auth,
);

// Read personal data from AUTH certificate
final data = await readPersonalData(
  can: '123456',
  pin: 'mySecurePin',
  certificateType: DnieCertificateType.auth,
);
print('Name: ${data.fullName}, NIF: ${data.nif}');
```

## Certificate Types

| Type | Enum | Use Case |
|------|------|----------|
| FIRMA | `DnieCertificateType.sign` | Digital signatures |
| AUTENTICACION | `DnieCertificateType.auth` | Identity authentication (Cl@ve) |

## Error Handling

All operations throw typed `DnieError` subclasses. The `DnieWrongPinError` includes a `remainingRetries` count:

```dart
try {
  await verifyPin(can: myCan, pin: myPin);
} on DnieWrongPinError catch (e) {
  print('Wrong PIN. ${e.remainingRetries} retries left.');
} on DnieLockedPinError {
  print('Card is locked!');
} on DnieError catch (e) {
  print('Error: ${e.message}');
}
```

See the [root README](../README.md) for full API documentation, platform setup, and error reference.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
