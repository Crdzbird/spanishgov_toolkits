# felectronic_dnie

A Flutter plugin for reading and signing with the Spanish electronic DNIe (Documento Nacional de Identidad electronico) via NFC.

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

## Features

- **NFC availability** -- check that NFC hardware is present and switched on
- **Probe card** -- tell whether a card is a DNIe, with no CAN or PIN
- **Verify PIN** -- check the CAN and PIN without signing anything
- **Sign** -- sign bytes or text with the signing or authentication certificate
- **Certificates** -- read the raw certificate, or its parsed X.509 details
- **Personal data** -- name, NIF and country from the certificate
- **DnieSession** -- enter the CAN and PIN once, then use them for every operation
- **Workflows** -- `checkReadiness`, `readFullIdentity`, `probeAndSign`
- **Cancellation** -- stopping an operation ends it with `DnieCancelledError`
- **Validators and shorthand** -- CAN, PIN and NIF checks, and helpers on every result type

## Platform setup

### Android

Nothing to add: the plugin declares the NFC permission itself. The card has to
sit over the phone's NFC antenna, which on most phones is in the upper half of
the back.

### iOS

Core NFC needs three things in the app, or no session will start:

1. The **Near Field Communication Tag Reading** capability, added in Xcode
   under Signing & Capabilities. It requires a paid developer account.
2. A usage description in `Info.plist`:

   ```xml
   <key>NFCReaderUsageDescription</key>
   <string>NFC access is required to read your electronic DNIe card.</string>
   ```

3. The application identifiers the DNIe answers to, also in `Info.plist`:

   ```xml
   <key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
   <array>
     <string>A00000000386980701</string>
     <string>A000000063504B43532D3135</string>
     <string>A0000002471001</string>
     <string>A0000002472001</string>
     <string>00000000000000</string>
   </array>
   ```

The first `pod install` downloads the j2objc runtime the iOS implementation
links against (about 70 MB, checked against a pinned SHA-256); see
[felectronic_dnie_ios](https://pub.dev/packages/felectronic_dnie_ios). Apps that
use Swift Package Manager need no changes: Flutter builds this plugin through
CocoaPods.

## Usage

```dart
import 'package:felectronic_dnie/felectronic_dnie.dart';
```

### DnieSession

The simplest way in. The CAN and PIN are checked for format when the session is
created, so a typo fails before NFC is touched.

```dart
final session = DnieSession(can: '123456', pin: 'mySecurePin');

final signed = await session.signText('Hello, DNIe!');
final details = await session.certificateDetails();
final person = await session.personalData();

final login = await session.auth.readCertificate(); // the authentication certificate
await session.stop(); // cancels a running operation
```

`session.auth` and `session.signing` return copies of the session that use the
other certificate. `readFullIdentity()`, `checkReadiness()` and
`probeAndSign(data)` are available on the session too.

### Single operations

Every operation is also a top-level function. Whitespace around the CAN and PIN
is ignored.

```dart
final nfc = await checkNfcAvailability();
if (!nfc.isReady) print(nfc.statusMessage);

final probe = await probeCard();
print('Is a DNIe: ${probe.isValidDnie}');

await verifyPin(can: '123456', pin: 'mySecurePin');

final signed = await sign(
  data: utf8.encode('Hello, DNIe!'),
  can: '123456',
  pin: 'mySecurePin',
  certificateType: DnieCertificateType.auth,
  timeout: const Duration(seconds: 20),
);
```

`timeout` is how long to wait for the card; it defaults to `dnieDefaultTimeout`
(30 seconds). Android clamps it to between 3 and 30 seconds, and iOS does not
use it, because Core NFC ends every session after 60 seconds on its own.

### Workflows

```dart
final readiness = await checkReadiness(can: '123456', pin: 'mySecurePin');
if (!readiness.isReady) print(readiness.error?.message);

final identity = await readFullIdentity(can: '123456', pin: 'mySecurePin');
print('${identity.personalData.displayName}, ${identity.nif}');

final result = await probeAndSign(
  data: utf8.encode('Sign this'),
  can: '123456',
  pin: 'mySecurePin',
); // throws DnieNotDnieError, without signing, if the card is not a DNIe
```

`checkReadiness` never throws a `DnieError`; it stops at the first step that
fails and reports it in `readiness.error`. `readFullIdentity` takes two reads
of the card.

### Validators and shorthand

```dart
'123456'.isValidCan;             // true
input.validateCan()?.message;    // null, or why it is not a CAN
'mySecurePin'.isValidPin;        // 8 to 16 characters
'12345678Z'.isValidNif;          // checks the NIF or NIE control letter

nfc.isReady;                     // available and enabled
info.isValidAt(DateTime(2027));  // within the validity period
info.remaining;                  // time left, as a Duration
info.expiryStatus;               // "Expires in 45 days", "Expired", ...
signed.certificateDer;           // the certificate's DER bytes
signed.parsedCertificate;        // the full X.509 parse
person.displayName;              // "Maria de la Cruz Garcia"
person.certificateKind;          // DnieCertificateType.sign or .auth
```

## Certificate types

| Certificate | Enum | Use |
|---|---|---|
| FIRMA | `DnieCertificateType.sign` | Digital signatures |
| AUTENTICACIÓN | `DnieCertificateType.auth` | Identity authentication (Cl@ve) |

## Error handling

Every operation throws a subclass of the sealed `DnieError`:

| Error | Meaning |
|---|---|
| `DnieTimeoutError` | No card was presented in time |
| `DnieCancelledError` | The operation was stopped, or the user dismissed the iOS NFC sheet |
| `DnieWrongPinError` | Wrong PIN; `remainingRetries` says how many tries are left, when the card tells |
| `DnieWrongCanError` | Wrong CAN |
| `DnieLockedPinError` | The PIN is locked after too many wrong attempts |
| `DnieNotDnieError` | The card is not a DNIe |
| `DnieDamagedError` | The card is damaged |
| `DnieExpiredCertificateError` | The certificate has expired |
| `DnieUnderageError` | An underage document, which cannot sign |
| `DnieConnectionError` | The NFC connection was lost |
| `DnieProviderError` | The cryptographic provider could not be created |
| `DniePrivateKeyError` | The private key could not be used |
| `DnieSigningError` | The signature itself failed |
| `DnieCardTagError` | The NFC tag could not be read |
| `DnieUnknownError` | Anything else, with the native message |

`isRetryable` and `isCredentialError` group them by what the user can do:

```dart
try {
  await session.signText('Hello');
} on DnieWrongPinError catch (e) {
  if (e.isLastAttempt) print('One more wrong PIN locks the card.');
} on DnieError catch (e) {
  print(e.isRetryable ? 'Hold the card still and try again.' : e.message);
}
```

## Migrating from 1.x

- `timeout` is a `Duration`: replace `timeout: 10` with
  `timeout: const Duration(seconds: 10)`.
- `probeAndSign` returns `SignedData` and throws `DnieNotDnieError` instead of
  returning `null`.
- `stopSign()` and `DnieSession.stop()` now end the stopped operation with
  `DnieCancelledError`; before, its future never completed.
- `DnieWrongPinError.remainingRetries` is `int?`, and `null` rather than `-1`
  when unknown.
- `CertificateExpiryStatus.message` and `withDays()` are replaced by
  `describe(daysLeft)`.
- `SignedData.fromMap` and `SignedData.fromJson` are removed.
- Models and errors are `final` classes.

The [repository](https://github.com/Crdzbird/spanishgov_toolkits) has an
example app that exercises every operation.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
