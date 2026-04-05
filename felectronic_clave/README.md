# felectronic_clave

Cl@ve authentication for Spanish government services. Provides a clean API for authenticating via Spain's Cl@ve identity system using OAuth/OIDC.

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

## Features

- **Cl@ve PIN** -- temporary 24-hour PIN via SMS
- **Cl@ve Permanente** -- permanent password (Social Security)
- **Electronic Certificate** -- client-side X.509 certificate (AFIRMA)
- **European Credential** -- eIDAS / STORK cross-border authentication
- **Cl@ve Movil** -- push notification to the Cl@ve mobile app
- **Token Management** -- secure storage, refresh, and validation
- **LOA Elevation** -- re-authenticate at a higher Level of Assurance
- **Document Validation** -- DNI/NIE check-letter and format validation

## Installation

```yaml
dependencies:
  felectronic_clave: ^0.1.0
```

### Dependencies

This package uses:
- `flutter_appauth` for OAuth/OIDC flows
- `flutter_secure_storage` for encrypted token persistence
- `http` for Cl@ve Movil API calls

Follow the [flutter_appauth setup guide](https://pub.dev/packages/flutter_appauth) for platform-specific configuration (redirect URI schemes, etc.).

## Configuration

Create a `ClaveConfig` with your OAuth endpoints and client credentials:

```dart
import 'package:felectronic_clave/felectronic_clave.dart';

final config = ClaveConfig(
  discoveryUrl: 'https://auth-api.redsara.es/auth/realms/.../.well-known/openid-configuration',
  clientId: 'my-client-id',
  redirectUri: 'com.example.app://login-callback',
  clientSecret: 'my-client-secret',
  userInfoUrl: 'https://auth-api.redsara.es/auth/realms/.../protocol/openid-connect/userinfo',
  logoutUrl: 'https://auth-api.redsara.es/auth/realms/.../protocol/openid-connect/logout',
  defaultLoa: ClaveLoaLevel.low,
  enabledMethods: [
    ClaveAuthMethod.clavePin,
    ClaveAuthMethod.clavePermanente,
    ClaveAuthMethod.electronicCertificate,
    ClaveAuthMethod.claveMovil,
  ],
  // Required only for Cl@ve Movil:
  claveMobileCreateUrl: 'https://...',
  claveMobileValidateUrl: 'https://...',
);
```

Use the `ClaveConfigX` extension to validate your config:

```dart
if (!config.isValid) throw Exception('Invalid configuration');
if (!config.hasClaveMobileUrls) print('Cl@ve Movil not configured');
```

## Usage

### Login

```dart
final repo = ClaveRepository(config);

// Login with Cl@ve PIN
final result = await repo.login(method: ClaveAuthMethod.clavePin);
print(result.accessToken);

// Login with a specific LOA level
final elevated = await repo.login(
  method: ClaveAuthMethod.clavePermanente,
  loa: ClaveLoaLevel.medium,
);
```

Note: `ClaveAuthMethod.electronicCertificate` always uses `ClaveLoaLevel.medium` regardless of the `loa` parameter.

### Token Management

Tokens are persisted in encrypted secure storage automatically after login.

```dart
// Get stored token
final token = await repo.getStoredToken();

// Refresh token
final newToken = await repo.refreshToken();

// Validate token against the userInfo endpoint
final claims = await repo.validateToken();
if (claims.isEmpty) print('Token is invalid');

// Extract NIF from a JWT token
final nif = repo.getNifFromToken(token!);

// Logout and clear tokens
await repo.logout();
```

### LOA Elevation

Re-authenticate at a higher Level of Assurance. If the elevated login fails, the previous tokens are restored automatically.

```dart
final result = await repo.elevateLoaLevel(
  method: ClaveAuthMethod.clavePermanente,
  loa: ClaveLoaLevel.high,
);
```

### Cl@ve Movil Flow

Cl@ve Movil sends a push notification to the user's Cl@ve app. The user confirms on their phone, and the app polls for the result.

#### Manual Polling

```dart
// Step 1: Send notification
final session = await repo.sendNotificationCode(
  document: '12345678Z',  // DNI
  contrast: '01-01-2025', // Validity date for DNI
);
print('Show code to user: ${session.displayCode}');

// Step 2: Poll for result
ClaveAuthResult? authResult;
while (authResult == null) {
  try {
    authResult = await repo.validateNotificationCode(session: session);
  } on ClaveIdleError {
    await Future.delayed(Duration(seconds: 5));
  }
}
```

For NIE documents, the `contrast` is the support number (e.g. `C12345678`).

#### Stream-Based Polling with ClaveMobilePoller

A cleaner alternative using a stream:

```dart
final poller = ClaveMobilePoller(repo);

await for (final status in poller.poll(session: session)) {
  switch (status) {
    case ClavePollWaiting(:final elapsedSeconds):
      print('Waiting... ${elapsedSeconds}s');
    case ClavePollSuccess(:final result):
      print('Authenticated: ${result.accessToken}');
    case ClavePollError(:final error):
      print('Failed: ${error.message}');
  }
}

// Cancel polling early if needed
poller.cancel();
```

The poller accepts optional parameters:
- `initialDelay` -- wait before first poll (default: 20 seconds)
- `interval` -- time between polls (default: 5 seconds)
- `timeout` -- maximum polling duration (default: 5 minutes)

## Document Validation

### DocumentValidator

Static utility for validating Spanish identity documents:

```dart
DocumentValidator.isValidDni('12345678Z'); // true/false (modulo-23 check)
DocumentValidator.isValidNie('X1234567L'); // true/false
DocumentValidator.isValid('12345678Z');    // validates either DNI or NIE

DocumentValidator.isValidSupportNumber('C12345678'); // NIE support number
DocumentValidator.isValidContrastDate('01-01-2025'); // dd-MM-yyyy

DocumentValidator.contrastTypeFor('12345678Z'); // 'date'
DocumentValidator.contrastTypeFor('X1234567L'); // 'support'
```

### String Extensions

Convenient validation directly on strings:

```dart
'12345678Z'.isValidDni;          // true
'X1234567L'.isValidNie;          // true
'12345678Z'.isValidDocument;     // true
'12345678Z'.documentType;        // 'DNI'
'C12345678'.isValidSupportNumber; // true
'01-01-2025'.isValidContrastDate; // true

// For form validation — returns error message or null
final error = userInput.validateDocument();
final contrastError = dateInput.validateContrast(isDni: true);
```

## Models and Enums

### ClaveAuthMethod

| Value | IDP String | Description |
|-------|-----------|-------------|
| `clavePin` | `PIN24H` | Temporary 24-hour PIN via SMS |
| `clavePermanente` | `SEGSOC` | Permanent password (Social Security) |
| `electronicCertificate` | `AFIRMA` | Client-side X.509 certificate |
| `europeanCredential` | `EIDAS` | eIDAS / STORK |
| `claveMovil` | `CLVMOVIL` | Push notification to Cl@ve app |

### ClaveLoaLevel

| Value | Level | Description |
|-------|:-----:|-------------|
| `low` | 1 | Password or PIN-based |
| `medium` | 2 | Two-factor or certificate-based |
| `high` | 3 | Qualified electronic signature |

### ClaveAuthResult

| Field | Type | Description |
|-------|------|-------------|
| `accessToken` | `String` | OAuth access token |
| `refreshToken` | `String?` | OAuth refresh token |
| `expiresIn` | `int?` | Token expiry in seconds |

Extensions (`ClaveAuthResultX`): `hasRefreshToken`, `expiresAt`, `isTokenExpired`.

### ClaveMobileSession

| Field | Type | Description |
|-------|------|-------------|
| `token` | `String` | Session token for polling |
| `verificationCode` | `String` | Code shown to user |
| `document` | `String` | DNI or NIE used |

Extensions (`ClaveMobileSessionX`): `isActive`, `displayCode` (zero-padded to 6 digits).

## Error Handling

All errors extend the sealed `ClaveError` class:

| Error | Description |
|-------|-------------|
| `ClaveAuthCancelledError` | User cancelled the OAuth flow |
| `ClaveInvalidContrastError` | Contrast data does not match the document |
| `ClaveRequestAlreadySentError` | A Cl@ve Movil notification is already pending |
| `ClaveSessionExpiredError` | Session or token has expired |
| `ClaveRefusedError` | Authentication was refused |
| `ClaveDiscoveryFailedError` | Cannot reach the OpenID Connect discovery endpoint |
| `ClaveIdleError` | Cl@ve Movil validation is still pending (keep polling) |
| `ClaveUnknownError` | Unexpected error with a message |

```dart
try {
  await repo.login(method: ClaveAuthMethod.clavePin);
} on ClaveAuthCancelledError {
  print('User cancelled');
} on ClaveDiscoveryFailedError {
  print('Network issue');
} on ClaveError catch (e) {
  print('Cl@ve error: ${e.message}');
}
```

## Cleanup

Call `dispose()` when the repository is no longer needed to release HTTP resources:

```dart
repo.dispose();
```

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
