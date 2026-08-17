# Changelog

## 1.0.0

- The @firma three-phase signing protocol in pure Dart: pre-sign, sign,
  post-sign, producing CAdES, PAdES and XAdES envelopes.
- Network and private key are both caller-supplied, so the package performs no
  I/O and holds no key material.
- Typed failures distinguishing transport, service and protocol errors,
  including the service's `ERR-` responses that arrive with HTTP 200.
