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
  felectronic_clave: ^1.0.0
```

### Dependencies

This package uses:
- `flutter_appauth` for OAuth/OIDC flows
- `flutter_secure_storage` for encrypted token persistence
- `http` for Cl@ve Movil API calls

### Registering the redirect scheme

The OAuth redirect comes back to your app through a custom URL scheme, and it
has to be registered on **both** platforms. Registering it on only one is a
quiet failure: the browser opens, the user authenticates, and the callback
never arrives.

**Android** — in `android/app/build.gradle.kts`:

```kotlin
manifestPlaceholders["appAuthRedirectScheme"] = "com.example.app"
```

**iOS/macOS** — in `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.example.app</string>
    </array>
  </dict>
</array>
```

The scheme must match the one in `ClaveConfig.redirectUri` — for
`com.example.app://login-callback`, the scheme is `com.example.app`. See the
[flutter_appauth setup guide](https://pub.dev/packages/flutter_appauth) for the
full detail.

## Configuration

Create a `ClaveConfig` with your OAuth endpoints and client credentials:

```dart
import 'package:felectronic_clave/felectronic_clave.dart';

final config = ClaveConfig(
  discoveryUrl: 'https://auth-api.redsara.es/auth/realms/.../.well-known/openid-configuration',
  clientId: 'my-client-id',
  redirectUri: 'com.example.app://login-callback',
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

### `clientSecret` is optional, and should usually stay unset

A mobile app cannot keep a secret: anyone can extract it from the distributed
binary. RFC 8252 therefore says a native app should be registered as a *public*
client and rely on PKCE, which `flutter_appauth` performs automatically.

`clientSecret` remains available because some Cl@ve deployments register their
clients as confidential and reject a request without one. If yours does, pass
it — but know that it is not actually secret, and that the security of the flow
rests on PKCE and on the registered redirect URI rather than on it.

`ClaveConfigX.isValid` deliberately does not check it.

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

`ClaveAuthMethod.supportsLoa` encodes one constraint the gateway will not
negotiate: **Cl@ve PIN cannot reach the high level of assurance.** A PIN sent
by SMS is not a qualified credential, and asking for it produces a failure
rather than a downgrade, so `login` refuses the pairing before opening the
browser.

`stork` and `europeanCredential` are separate providers (`STORK` and `EIDAS`),
not two names for one.


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

Two further exceptions come from the HTTP layer and are not `ClaveError`s;
`ClaveRepository` maps them for you, but they are exported so a caller driving
`ClaveHttpClient` directly can catch them:

| Exception | Meaning |
|-----------|---------|
| `ClaveApiException` | the server answered with a non-2xx; carries status and body |
| `ClaveNetworkException` | the server could not be reached, or the request timed out |

### What the errors distinguish

Three distinctions matter, and each was wrong in an earlier revision:

- **Cancelled vs failed.** Every failure of the authorize-and-exchange call
  arrives with the same platform code, because that code is the *method name*,
  not a cause. Only `FlutterAppAuthUserCancelledException` means the user
  cancelled; a wrong client secret or an unreachable IDP no longer masquerades
  as one.
- **Unreachable vs rejected.** A refresh that fails because the network is down
  leaves the session intact — only a refusal from the server clears it. The
  same holds for `validateToken`, where a 503 from userInfo used to log the
  user out just as a 401 did.
- **Logged out locally, regardless.** `logout()` clears the device's tokens
  even when the server cannot be told.

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

## Reference implementation

Every wire-level decision here follows the Spanish government App Factory's own
Flutter client, which runs against the live Cl@ve gateway. Where this package
and that client disagreed, the client was taken as correct — it is the only one
of the two that has ever been answered by the real service.

That diff found four things this package had wrong, none of which its tests
could have caught, because the fakes were written from the same reading as the
code:

- **The notification request had the wrong shape.** It sent
  `{"doc":…,"contraste":…}`; the service takes a key/value envelope,
  `{"params":[{"key":"doc","value":…},…]}`. Cl@ve Movil could never have
  worked.
- **Logout was a different request.** The access token belongs in an
  `Authorization: Bearer` header, not in a `token` form field.
- **Half the failures were unreadable.** The two Movil endpoints are separate
  services with separate error shapes — the notification API answers
  `{"messages":[{"details":…}]}`, and validation goes to Keycloak, which
  answers `{"error_description":…}`. Only the first was parsed.
- **`STORK` was missing.** The gateway treats `STORK` and `EIDAS` as different
  identity providers.

Two differences are deliberate. The reference sends its default level of
assurance as `LoaTypes.low.toString()`, which puts the literal text
`"LoaTypes.low"` on the wire where a digit belongs; this package sends the
number. And the reference clears the device's tokens only when the logout
request succeeds, keeps no polling timeout, and ends the session on any refresh
failure including a network one — the handling here is described under
[What the errors distinguish](#what-the-errors-distinguish).

### The browser session

Two options carry over from the reference and are on by default, because
neither is a detail a caller should have to discover:

- `preferEphemeralSession` runs the login in an ephemeral
  `ASWebAuthenticationSession`, so the government gateway neither reads nor
  leaves behind a Safari session belonging to the rest of the device.
- `promptLogin` sends `prompt=login`, so the gateway actually asks the user to
  authenticate instead of answering from a session it already has. This matters
  most when raising the level of assurance, where re-authentication is the
  entire point.

`allowInsecureConnections` also exists, defaults to false, and should stay that
way outside a government test gateway — it disables transport security for the
one exchange in this package that carries credentials.

## Status

| | Covered by tests | Matched to the reference | Run against the real service |
|---|---|---|---|
| Document and contrast validation, JWT parsing | yes | yes | n/a — pure functions |
| Request and response shapes, idp values | yes | yes | **no** |
| Error classification | yes | yes | **no** |
| OAuth login, refresh, logout | yes, against fakes | yes | **no** |
| Polling timing and lifecycle | yes, against fakes | yes | **no** |

**No request from this package has reached the real Cl@ve service.** The diff
against the reference is the strongest evidence available short of a live call,
and it is what found the defects above — the tests did not, because a fake
written from the same reading as the client agrees with it whether or not that
reading is right.

The example app exercises only the offline validators; it does not perform a
login.

## Cleanup

Call `dispose()` when the repository is no longer needed to release HTTP resources:

```dart
repo.dispose();
```

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
