# felectronic_x509

A pure Dart X.509 certificate parser with zero external dependencies. Parses DER, PEM, and base64-encoded certificates into structured objects.

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

## Features

- Parse X.509 certificates from DER bytes, PEM strings, or base64
- Extract subject and issuer distinguished names (CN, O, OU, C, etc.)
- Read validity period (notBefore / notAfter)
- Access serial number, version, and signature algorithm
- Parse extensions including key usage, basic constraints, and more
- Get public key algorithm, size, and raw bytes
- Low-level ASN.1 DER reader included
- No external dependencies beyond `dart:typed_data` and `dart:convert`

## Installation

```yaml
dependencies:
  felectronic_x509: ^1.0.0
```

## Usage

### Parse from DER bytes

```dart
import 'package:felectronic_x509/felectronic_x509.dart';

final cert = X509Parser.fromDer(derBytes);
print('Subject: ${cert.subject.commonName}');
print('Issuer: ${cert.issuer.organizationName}');
print('Valid until: ${cert.notValidAfter}');
```

### Parse from PEM string

```dart
final cert = X509Parser.fromPem(pemString);
print('Serial: ${cert.serialNumber}');
print('Version: v${cert.version}');
```

### Parse from base64

```dart
final cert = X509Parser.fromBase64(base64DerString);
print('Algorithm: ${cert.signatureAlgorithm}');
```

### Access certificate fields

```dart
final cert = X509Parser.fromDer(derBytes);

// Distinguished names
print(cert.subject.commonName);
print(cert.subject.organization);
print(cert.subject.country);
print(cert.issuer.commonName);

// Validity
print(cert.notValidBefore);
print(cert.notValidAfter);

// Public key
print(cert.publicKeyAlgorithm); // e.g. "RSA"
print(cert.publicKeySize);      // e.g. 2048

// Extensions
for (final ext in cert.extensions) {
  print('${ext.oid} critical=${ext.isCritical}');
}

// Raw data
print(cert.signatureBytes.length);
print(cert.derEncoded.length);
```

## Error handling

All parsing methods throw `FormatException` on invalid or malformed input:

```dart
try {
  final cert = X509Parser.fromDer(invalidBytes);
} on FormatException catch (e) {
  print('Failed to parse: $e');
}
```

## Architecture

The package is organized into two layers:

| Layer | Classes | Description |
|-------|---------|-------------|
| ASN.1 | `Asn1Reader`, `Asn1Object`, `Asn1Tag` | Low-level DER decoder |
| X.509 | `X509Parser`, `X509Certificate`, `X509Name`, `X509Extension`, `X509PublicKey` | High-level certificate model |

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
