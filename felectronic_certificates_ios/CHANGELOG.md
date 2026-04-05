# Changelog

## 1.0.0

- iOS implementation using Security.framework (no external dependencies).
- PKCS#12 import via SecPKCS12Import with Keychain storage.
- Certificate listing via SecItemCopyMatching with access group support.
- Signing via SecKeyCreateSignature with RSA and ECDSA algorithms.
- Trust chain validation via SecTrustEvaluateWithError.
- Public key extraction for server-side validation.
- Certificate deletion by serial number.
- Default selection persistence via UserDefaults.
