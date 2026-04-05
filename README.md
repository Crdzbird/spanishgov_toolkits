# felectronic_dnie

A suite of Flutter packages for building Spanish government-facing applications. Covers NFC-based DNIe signing, Cl@ve OAuth authentication, device certificate management, and X.509 certificate parsing.

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

## Packages

| Package | Description | Version |
|---------|-------------|---------|
| [`felectronic_dnie`](felectronic_dnie/) | NFC operations with the Spanish electronic DNIe | 1.0.0 |
| [`felectronic_clave`](felectronic_clave/) | Cl@ve OAuth/OIDC authentication for Spanish government services | 1.0.0 |
| [`felectronic_certificates`](felectronic_certificates/) | Device certificate management (import, sign, list, delete) | 1.0.0 |
| [`felectronic_x509`](felectronic_x509/) | Pure Dart X.509 certificate parser (no Flutter dependency) | 1.0.0 |

### Internal Packages

These are implementation details of the federated plugins above. You do not need to depend on them directly.

| Package | Description |
|---------|-------------|
| [`felectronic_dnie_platform_interface`](felectronic_dnie_platform_interface/) | Shared interface for DNIe platform implementations |
| [`felectronic_dnie_android`](felectronic_dnie_android/) | Android DNIe implementation |
| [`felectronic_dnie_ios`](felectronic_dnie_ios/) | iOS DNIe implementation |
| [`felectronic_certificates_platform_interface`](felectronic_certificates_platform_interface/) | Shared interface for certificate platform implementations |
| [`felectronic_certificates_android`](felectronic_certificates_android/) | Android certificate implementation |
| [`felectronic_certificates_ios`](felectronic_certificates_ios/) | iOS certificate implementation |

## Platform Support

| Package | Android | iOS | Pure Dart |
|---------|:-------:|:---:|:---------:|
| `felectronic_dnie` | API 28+ | iOS 13+ | |
| `felectronic_clave` | API 24+ | iOS 13+ | |
| `felectronic_certificates` | API 28+ | iOS 13+ | |
| `felectronic_x509` | | | All platforms |

## Security

These packages are developer tools for building authorized applications that interact with the Spanish electronic identity system. They follow these security principles:

- **No credential storage.** CAN, PIN, and passwords are passed through to native APIs and never persisted by the library.
- **No private key extraction.** The DNIe private key never leaves the physical card. Signing is performed on-card via NFC.
- **Cardholder consent required.** Every authenticated operation requires the physical card plus the cardholder's CAN and PIN.
- **Standard protocols only.** All communication uses documented standards: ISO 7816, PKCS#12, X.509, OAuth 2.0/OIDC.
- **Platform-native security.** Certificate storage uses Android KeyStore and iOS Keychain.

For vulnerability reporting, see [SECURITY.md](SECURITY.md).

## Architecture

```
felectronic_dnie                         (app-facing DNIe plugin)
  +-- felectronic_dnie_platform_interface  (platform interface + models)
  |     +-- felectronic_x509               (X.509 parser)
  +-- felectronic_dnie_android             (Android via Pigeon)
  +-- felectronic_dnie_ios                 (iOS via Pigeon)

felectronic_certificates                 (app-facing certificates plugin)
  +-- felectronic_certificates_platform_interface
  |     +-- felectronic_x509               (X.509 parser)
  +-- felectronic_certificates_android     (Android KeyStore + AAR)
  +-- felectronic_certificates_ios         (iOS Keychain)

felectronic_clave                        (pure Dart, no native code)

felectronic_x509                         (pure Dart, zero dependencies)
```

All native platform communication uses [Pigeon](https://pub.dev/packages/pigeon) for type-safe bindings.

## Quick Start

### felectronic_dnie -- NFC DNIe

Read, sign, and verify identity with the Spanish electronic DNIe via NFC.

```yaml
dependencies:
  felectronic_dnie: ^1.0.0
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

// Use DnieSession to avoid repeating credentials
final session = DnieSession(can: '123456', pin: 'mySecurePin');
final info = await session.certificateDetails();
final personal = await session.personalData();
print('${personal.fullName} - ${info.expiryStatus}');
```

See the [felectronic_dnie README](felectronic_dnie/README.md) for the full API reference.

### felectronic_clave -- Cl@ve Authentication

OAuth/OIDC authentication via Spain's Cl@ve identity system.

Supports: Cl@ve PIN, Cl@ve Permanente, Cl@ve Movil, Electronic Certificate, and European Credential (eIDAS).

```yaml
dependencies:
  felectronic_clave: ^1.0.0
```

```dart
import 'package:felectronic_clave/felectronic_clave.dart';

final repo = ClaveRepository(ClaveConfig(
  discoveryUrl: 'https://auth-api.redsara.es/.../openid-configuration',
  clientId: 'my-client-id',
  redirectUri: 'com.example.app://login-callback',
  clientSecret: 'my-secret',
  userInfoUrl: 'https://auth-api.redsara.es/.../userinfo',
  logoutUrl: 'https://auth-api.redsara.es/.../logout',
));

final result = await repo.login(method: ClaveAuthMethod.clavePin);
print(result.accessToken);
```

See the [felectronic_clave README](felectronic_clave/README.md) for the full API reference.

### felectronic_certificates -- Device Certificates

Import, sign with, list, and delete PKCS#12 certificates stored in the Android KeyStore or iOS Keychain.

```yaml
dependencies:
  felectronic_certificates: ^1.0.0
```

```dart
import 'package:felectronic_certificates/felectronic_certificates.dart';

// Select a certificate via the native picker
final session = await CertificateSession.select();
if (session != null) {
  print('Selected: ${session.certificate.displayName}');
  final sig = await session.sign(myData);
}
```

See the [felectronic_certificates README](felectronic_certificates/README.md) for the full API reference.

### felectronic_x509 -- X.509 Parser

Pure Dart X.509 certificate parser. No Flutter dependency, zero external packages.

```yaml
dependencies:
  felectronic_x509: ^1.0.0
```

```dart
import 'package:felectronic_x509/felectronic_x509.dart';

final cert = X509Parser.fromDer(derBytes);
print('Subject: ${cert.subject.commonName}');
print('Issuer: ${cert.issuer.organization}');
print('Algorithm: ${cert.signatureAlgorithmName}');
print('Key: ${cert.publicKeyAlgorithm} ${cert.publicKeySize}-bit');
print('OCSP: ${cert.ocspUrls}');
```

See the [felectronic_x509 README](felectronic_x509/README.md) for the full API reference.

## Development

### Prerequisites

- Flutter 3.22+
- Dart 3.4+
- Android: API 28+
- iOS: 13+

### Running Tests

```bash
# All packages
for pkg in felectronic_x509 felectronic_dnie felectronic_certificates felectronic_clave; do
  echo "=== $pkg ===" && (cd $pkg && flutter test 2>/dev/null || dart test)
done
```

### Regenerating Pigeon Bindings

```bash
cd felectronic_dnie_platform_interface && dart run pigeon --input pigeons/messages.dart
cd felectronic_certificates_platform_interface && dart run pigeon --input pigeons/messages.dart
```

## Contributing

Contributions are welcome. Please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Run `flutter analyze` and `flutter test` for affected packages
4. Commit your changes
5. Open a pull request

Please read [SECURITY.md](SECURITY.md) before contributing security-related changes.

## License

Copyright (c) 2025 DEVotion & Crdzbird

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
