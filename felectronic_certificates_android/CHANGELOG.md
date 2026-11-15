# Changelog

## 1.1.0

- Requires Flutter 3.44 and Dart 3.12.
- Migrates to built-in Kotlin: the plugin no longer applies the Kotlin Gradle
  Plugin, so apps stop warning about it and keep building once Flutter
  refuses plugins that apply it. Apps with built-in Kotlin on or off both
  build.

## 1.0.0

- Android implementation using CertificateSigner AAR and Android KeyChain API.
- System certificate picker via KeyChain.choosePrivateKeyAlias().
- Certificate import via CertificateSigner.importCertificate().
- Signing via AAR with KeyChain API fallback.
- Known-alias tracking in SharedPreferences for certificate listing.
- Set default by serial number via alias resolution.
