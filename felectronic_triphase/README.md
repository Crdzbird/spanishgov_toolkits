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

## Status

The protocol shape follows the Java implementation the Android build runs, and
is covered end to end by tests against a fake service. **No request in this
package has reached the real service.** If the protocol has been misread, the
fake and the client are wrong together and every test still passes — only a
live call settles that.
