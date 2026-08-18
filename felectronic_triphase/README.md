# felectronic_triphase

The @firma three-phase signing protocol, in pure Dart.

Produces CAdES, PAdES and XAdES signatures by delegating envelope construction
to the Spanish government's signing service while the private key stays on the
device. Shared by the electronic-certificate and DNIe signing paths, which run
the identical protocol and differ only in how the signature is produced.

Most callers do not use this package directly — `felectronic_certificates`
exposes it through `CertificateSession.sign(data, format: ...)`.

## How it works

Building an advanced signature needs the whole document and a good deal of
format-specific machinery, so the service does it in three phases:

1. **Pre-sign** — the client sends the document and its certificate; the
   service returns a session document naming the bytes to sign.
2. **Sign** — the client signs those bytes. This is the only phase that touches
   the private key, and the only phase where a certificate and a DNIe differ.
3. **Post-sign** — the client returns the session with the signature attached;
   the service assembles the envelope.

**The document is sent to the service.** The private key never leaves the
device, but the document does — that is inherent to the design, not a choice
this package makes. If you are signing confidential material, know this before
choosing a format.

## Supplying a transport

This package performs no network I/O of its own, so timeouts, proxying and
certificate pinning stay under your control. Adapting `package:http` takes a
few lines:

```dart
import 'package:http/http.dart' as http;
import 'package:felectronic_triphase/felectronic_triphase.dart';

TriphaseTransport httpTransport(http.Client client) {
  return (TriphaseRequest request) async {
    final response = await client.post(
      request.url,
      headers: const {'Content-Type': TriphaseRequest.contentType},
      body: request.body,
    );
    return TriphaseResponse(
      statusCode: response.statusCode,
      body: response.body,
    );
  };
}
```

Return the body for **any** status rather than throwing on non-2xx: the client
turns a non-2xx into a `TriphaseServiceException` with the body attached, which
is more useful than a bare status code. Throw only when the request could not
be made at all.

## Usage

```dart
final client = TriphaseClient(transport: httpTransport(http.Client()));

final signature = await client.sign(
  document: documentBytes,
  certificateBase64: base64.encode(certificateDer),
  format: SignatureFormat.pades,
  algorithm: SignatureAlgorithm.sha256withRsa,
  signPkcs1: (payload) => signWithYourKey(payload),
);
```

### `signPkcs1` is a full signature, not a modular exponentiation

The service expects the algorithm named in the request to be applied whole: the
payload is hashed, then signed. On iOS, `SecKeyCreateSignature` with a
`rsaSignatureMessagePKCS1v15SHA*` algorithm does exactly this. A DNIe reaches
the same result by hashing on the device and letting the card apply PKCS#1 to
the resulting DigestInfo.

Implementing it as raw RSA over the payload yields a signature the service
still accepts at post-sign, and a verifier rejects much later.

## Errors

Every failure is typed, so a caller can tell a retryable network problem from a
rejected document:

| Exception | Meaning |
| --- | --- |
| `TriphaseTransportException` | the service could not be reached |
| `TriphaseServiceException` | it answered, but with a failure; carries the status and body |
| `TriphaseProtocolException` | the answer did not have the shape the protocol requires |

Note that the service reports some of its own failures with HTTP 200 and an
`ERR-` body; those surface as `TriphaseServiceException`.

## Reference implementation

Three implementations of this protocol exist in this repository. Only one has
ever run against the real service:

| | Runs today | |
| --- | --- | --- |
| `TriPhaseSignerManager` (Kotlin, Android) | yes | the reference |
| `ThreePhaseSigningService` (Swift, iOS) | no — its pod has never linked | |
| this package | not yet | matched against the Kotlin |

Every encoding decision here follows the Kotlin. That matters more than it
sounds — where the two platform implementations disagreed, the Swift was
wrong, because it has never run to be proved otherwise. It sent the
certificate as standard base64 rather than URL-safe, and defaulted to XAdES
where Android sent CAdES, so the same call produced a different envelope
depending on the device. Both are now aligned to Android.

One spelling is worth calling out because it looks like a mistake and is not:
the formats go on the wire **lowercase** (`cades`, `pades`, `xades`) even
though the standards capitalize them, while the algorithms keep their
mixed-case Java spelling (`SHA512withRSA`). Both platform implementations do
this. Tidying the formats into `CAdES` would be a change the service never
asked for.

## What has been diffed against the Kotlin

The whole protocol surface, line by line:

- endpoint, method and `Content-Type`
- request field names, order, and when `params` is present
- every encoding: URL-safe with padding for `cert`, `doc` and `session`;
  standard for `params`
- `format` lowercase, algorithm mixed case
- pre-sign response: base64 to XML
- `PRE` extraction and decoding
- signing as a full hash-then-sign
- `PK1` insertion position, and preserving the document as text
- post-sign response: plain text, `OK` prefix required, then decode
- `ERR-` detection

Three differences are deliberate. Failures carry the response body, where
Android reports only the HTTP status text. The session is located by parsing
rather than by regex, which tolerates a `PRE` value that spans lines. And the
network and key are the caller's, so this package holds neither.

The certificate chain matches: Android sends every certificate
comma-separated, and so does this. `certificateBase64` takes that form —
`TriphaseRequests.certificateChain` builds it — and the separator survives
the URL-safe rewrite because it is not part of any base64 value. Callers
that can only supply a leaf still work, but a service that does not already
hold the issuer needs the intermediates to validate.

## Status

Covered end to end by tests against a fake service. **No request from this
package has reached the real service.** The diff above is the strongest
evidence available short of a live call, and it is what found the defects
this package shipped with — the tests did not, because the fake was written
from the same misreading as the client.
