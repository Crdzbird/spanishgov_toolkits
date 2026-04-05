# Changelog

## 1.0.0

- Android implementation using CertificateSigner AAR and Android KeyChain API.
- System certificate picker via KeyChain.choosePrivateKeyAlias().
- Certificate import via CertificateSigner.importCertificate().
- Signing via AAR with KeyChain API fallback.
- Known-alias tracking in SharedPreferences for certificate listing.
- Set default by serial number via alias resolution.
