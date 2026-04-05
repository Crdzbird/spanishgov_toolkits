# Changelog

## 1.0.0

- Pure Dart ASN.1 DER reader with support for all common tag types.
- X.509 certificate parser from DER, PEM, and base64 input.
- Full subject and issuer Distinguished Name parsing with typed accessors.
- Certificate validity dates, serial number, and signature algorithm extraction.
- Public key algorithm and size detection (RSA, EC).
- Extension parsing: key usage, extended key usage, SAN, basic constraints.
- CRL distribution points and OCSP responder URL extraction.
- Certificate policy OID extraction.
- PEM encoding from DER bytes.
- Zero external dependencies.
