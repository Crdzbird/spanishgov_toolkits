# Security Policy

## Overview

The felectronic suite provides developer tools for integrating with the Spanish electronic identity (DNIe) system, device certificate management, and Cl@ve authentication. These packages interact with sensitive cryptographic operations and identity data.

## Security Design Principles

- **No credential storage.** CAN, PIN, and passwords are passed through to native APIs and never persisted by the library.
- **No private key extraction.** The DNIe private key never leaves the physical card. Signing operations are performed on-card via NFC.
- **Standard protocols only.** All communication uses documented standards: ISO 7816 (NFC), PKCS#12, X.509, OAuth 2.0/OIDC.
- **Cardholder consent required.** Every authenticated operation requires the physical card plus the cardholder's CAN and PIN.
- **Platform-native security.** Certificate storage uses Android KeyStore and iOS Keychain, both hardware-backed when available.

## Supported Versions

| Package | Version | Supported |
|---------|---------|:---------:|
| All packages | 0.1.x | Yes |

## Reporting a Vulnerability

If you discover a security vulnerability in any of these packages, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please email: **crdzbird@gmail.com**

Include:
- A description of the vulnerability
- Steps to reproduce
- The affected package(s) and version(s)
- Any potential impact assessment

We will acknowledge receipt within 48 hours and aim to provide a fix or mitigation within 7 days for critical issues.

## Scope

The following are in scope for security reports:

- Credential leakage (CAN, PIN, tokens, private keys)
- Bypass of authentication requirements
- Injection vulnerabilities in native platform code
- Insecure storage of sensitive data
- Man-in-the-middle vulnerabilities in network communication

The following are out of scope:

- Vulnerabilities in the underlying platform (Android, iOS, Flutter)
- Issues with the jmulticard library or CertificateSigner AAR
- Denial of service via NFC proximity
- Social engineering attacks

## Responsible Use

These packages are intended for building authorized government-facing applications. They require the cardholder's physical card and knowledge of the CAN and PIN to operate. The X.509 certificate parser reads only the public portion of certificates, which is by definition public information.

By using these packages, you agree to comply with applicable laws and regulations regarding electronic identity and digital signatures in your jurisdiction.
