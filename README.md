# felectronic_dnie

A suite of Flutter packages for building Spanish government-facing applications. Covers NFC-based DNIe signing, Cl@ve OAuth authentication, and device certificate management.

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

## Packages

| Package | Description | Version |
|---------|-------------|---------|
| [`felectronic_dnie`](felectronic_dnie/) | NFC operations with the Spanish electronic DNIe | 0.1.0 |
| [`felectronic_clave`](felectronic_clave/) | Cl@ve OAuth/OIDC authentication for Spanish government services | 0.1.0 |
| [`felectronic_certificates`](felectronic_certificates/) | Device certificate management (import, sign, list, delete) | 0.1.0 |

Each package can be used independently.

## Platform Support

| Package | Android | iOS |
|---------|:-------:|:---:|
| `felectronic_dnie` | API 24+ | iOS 13+ |
| `felectronic_clave` | API 24+ | iOS 13+ |
| `felectronic_certificates` | API 28+ | iOS 13+ |

## Quick Start

### felectronic_dnie -- NFC DNIe

Read, sign, and verify identity with the Spanish electronic DNIe via NFC.

```yaml
dependencies:
  felectronic_dnie: ^0.1.0
```

```dart
import 'package:felectronic_dnie/felectronic_dnie.dart';

// Check NFC availability
final nfc = await checkNfcAvailability();
if (!nfc.isReady) print(nfc.statusMessage);

// Probe card (no PIN required)
final probe = await probeCard();
if (probe.isValidDnie) {
  // Sign data
  final result = await sign(
    data: utf8.encode('Hello, DNIe!'),
    can: '123456',
    pin: 'mySecurePin',
  );
}

// Or use DnieSession for repeated operations
final session = DnieSession(can: '123456', pin: 'mySecurePin');
final identity = await readFullIdentity(
  can: '123456', pin: 'mySecurePin',
);
print('${identity.fullName} - ${identity.nif}');
```

See the [felectronic_dnie README](felectronic_dnie/README.md) for full documentation.

### felectronic_clave -- Cl@ve Authentication

OAuth/OIDC authentication via Spain's Cl@ve identity system (Cl@ve PIN, Permanente, Movil, Electronic Certificate, eIDAS).

```yaml
dependencies:
  felectronic_clave: ^0.1.0
```

```dart
import 'package:felectronic_clave/felectronic_clave.dart';

final config = ClaveConfig(
  discoveryUrl: 'https://auth-api.redsara.es/.../openid-configuration',
  clientId: 'my-client-id',
  redirectUri: 'com.example.app://login-callback',
  clientSecret: 'my-secret',
  userInfoUrl: 'https://auth-api.redsara.es/.../userinfo',
  logoutUrl: 'https://auth-api.redsara.es/.../logout',
);

final repo = ClaveRepository(config);
final result = await repo.login(method: ClaveAuthMethod.clavePin);
print(result.accessToken);
```

See the [felectronic_clave README](felectronic_clave/README.md) for full documentation.

### felectronic_certificates -- Device Certificates

Import, sign with, list, and delete PKCS#12 certificates stored in the Android KeyStore or iOS Keychain.

```yaml
dependencies:
  felectronic_certificates: ^0.1.0
```

```dart
import 'package:felectronic_certificates/felectronic_certificates.dart';

// Import a PKCS#12 file
await importCertificate(pkcs12Bytes, password: 'cert-password');

// List all certificates
final certs = await getAllCertificates();
for (final cert in certs) {
  print('${cert.displayName} - ${cert.expiryStatus}');
}

// Sign data with the default certificate
final signature = await signWithDefaultCertificate(myData);
```

See the [felectronic_certificates README](felectronic_certificates/README.md) for full documentation.

## Architecture

```
felectronic_dnie/                  <-- App-facing DNIe plugin
  felectronic_dnie_platform_interface/  <-- Platform interface + models
  felectronic_dnie_android/             <-- Android implementation (Pigeon)
  felectronic_dnie_ios/                 <-- iOS implementation (Pigeon)

felectronic_certificates/          <-- App-facing certificates plugin
  felectronic_certificates_platform_interface/
  felectronic_certificates_android/     <-- Android (AAR + Pigeon)
  felectronic_certificates_ios/         <-- iOS (Keychain + Pigeon)

felectronic_clave/                 <-- Pure Dart (no native code)
```

All native platform communication uses [Pigeon](https://pub.dev/packages/pigeon) for type-safe bindings.

## Development

### Prerequisites

- Flutter 3.22+
- Dart 3.4+
- Android: API 24+ (28+ for certificates)
- iOS: 13+

### Running Tests

```bash
# Run tests for a specific package
cd felectronic_dnie && flutter test
cd felectronic_clave && flutter test
cd felectronic_certificates && flutter test
```

### Regenerating Pigeon Bindings

```bash
cd felectronic_dnie_platform_interface
dart run pigeon --input pigeons/messages.dart

cd felectronic_certificates_platform_interface
dart run pigeon --input pigeons/messages.dart
```

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
