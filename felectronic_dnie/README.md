# felectronic_dnie

A Flutter plugin for reading and signing with the Spanish electronic DNIe (Documento Nacional de Identidad electronico) via NFC.

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

## Features

- **NFC Availability** -- check if NFC hardware is available and enabled
- **Probe Card** -- detect if an NFC card is a valid DNIe (no PIN required)
- **Verify PIN** -- validate CAN + PIN credentials without signing
- **Sign Data** -- sign arbitrary bytes with the DNIe private key
- **Read Certificate** -- read the raw signing or authentication certificate
- **Certificate Details** -- parse X.509 subject, issuer, validity, and serial
- **Personal Data** -- extract name, NIF, country from the certificate
- **Certificate Type Selection** -- choose between SIGN (FIRMA) and AUTH (AUTENTICACION)
- **DnieSession** -- store credentials once and reuse for multiple operations
- **Workflows** -- `checkReadiness`, `readFullIdentity`, `probeAndSign`
- **Validators** -- CAN and PIN format validation via string extensions
- **Model Extensions** -- convenience helpers on all result types

## Usage

```dart
import 'package:felectronic_dnie/felectronic_dnie.dart';
```

### Basic Operations

```dart
// Check NFC availability
final nfc = await checkNfcAvailability();
if (!nfc.isReady) print(nfc.statusMessage);

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

// Read AUTH certificate
final authCert = await readCertificate(
  can: '123456',
  pin: 'mySecurePin',
  certificateType: DnieCertificateType.auth,
);

// Read personal data
final data = await readPersonalData(
  can: '123456',
  pin: 'mySecurePin',
);
print('Name: ${data.fullName}, NIF: ${data.nif}');
```

### DnieSession

Store CAN and PIN once to avoid repeating them. Validates credential format on construction.

```dart
final session = DnieSession(
  can: '123456',
  pin: 'mySecurePin',
  certificateType: DnieCertificateType.sign, // optional, default
  timeout: 30, // optional, default
);

final signed = await session.sign(myData);
final info = await session.certificateDetails();
final personal = await session.personalData();
await session.verifyCredentials();
await session.stop(); // cancel in-progress NFC operation
```

### Workflows

#### checkReadiness

Performs a full readiness check: NFC availability, card probe, and PIN verification. Never throws -- captures errors into the result.

```dart
final readiness = await checkReadiness(can: '123456', pin: 'mySecurePin');

if (readiness.isReady) {
  print('Card is ready for operations');
} else {
  if (!readiness.nfcStatus.isAvailable) print('No NFC hardware');
  if (!readiness.nfcStatus.isEnabled) print('NFC is disabled');
  if (!readiness.isValidDnie) print('Not a DNIe card');
  if (!readiness.isPinCorrect) print('Wrong CAN or PIN');
  if (readiness.error != null) print('Error: ${readiness.error!.message}');
}
```

#### readFullIdentity

Reads both personal data and certificate details in sequence. Note: this requires two NFC taps.

```dart
final identity = await readFullIdentity(
  can: '123456',
  pin: 'mySecurePin',
);
print('${identity.fullName} - ${identity.nif}');
print('Valid: ${identity.isValid}');
print('Expiry: ${identity.certificateInfo.expiryStatus}');
```

#### probeAndSign

Probes the card first, then signs only if it is a valid DNIe. Returns `null` if the card is not valid.

```dart
final result = await probeAndSign(
  data: utf8.encode('Sign this'),
  can: '123456',
  pin: 'mySecurePin',
);
if (result == null) {
  print('Card is not a valid DNIe');
}
```

### Input Validators

String extensions for validating CAN and PIN input in forms:

```dart
// CAN validation (must be exactly 6 digits)
'123456'.isValidCan;         // true
final canError = input.validateCan(); // null or error message

// PIN validation (8-16 characters)
'mySecurePin'.isValidPin;    // true
final pinError = input.validatePin(); // null or error message
```

### Model Extensions

#### NfcStatusX

```dart
nfc.isReady;        // isAvailable && isEnabled
nfc.statusMessage;  // human-readable status
```

#### CertificateInfoX

```dart
info.daysUntilExpiry;   // days remaining (negative if expired)
info.isExpiringSoon;    // expires within 30 days
info.isValidForSigning; // currently valid and not expired
info.expiryStatus;      // "Expires in 45 days", "Expired", etc.
```

#### SignedDataX

```dart
signed.hasSignature;      // signedData bytes present
signed.hasCertificate;    // certificate string present
signed.isComplete;        // both present
signed.signatureSizeBytes; // byte count
```

#### PersonalDataX

```dart
data.initials;      // "J.G."
data.isSigningCert; // FIRMA certificate
data.isAuthCert;    // AUTENTICACION certificate
```

## Certificate Types

| Type | Enum | Use Case |
|------|------|----------|
| FIRMA | `DnieCertificateType.sign` | Digital signatures |
| AUTENTICACION | `DnieCertificateType.auth` | Identity authentication (Cl@ve) |

## Error Handling

All operations throw typed `DnieError` subclasses:

| Error | Description |
|-------|-------------|
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
  print('Wrong PIN. ${e.remainingRetries} retries left.');
} on DnieLockedPinError {
  print('Card is locked!');
} on DnieError catch (e) {
  print('Error: ${e.message}');
}
```

See the [root README](../README.md) for platform setup instructions and the full monorepo overview.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
