# Changelog

## 3.0.0

### Breaking changes

- Requires `felectronic_dnie_platform_interface` 3.0.0.
- `signCades` answers `DSUnsupportedException` (`DnieUnsupportedError`): the
  three-phase CAdES flow is Android only. `sign` is unchanged and still signs
  on the phone.
- NFC missing, or an iOS version without tag reading, fails with
  `DSNfcUnavailableException` (`DnieNfcUnavailableError`) instead of
  `DnieProviderError`.

### Fixed

- `SignedData.certificate` from `sign` and `readCertificate` was URL-safe
  Base64. It is standard Base64, as on Android, which also lets
  `readCertificateDetails` and `readPersonalData` decode it.

## 2.0.0

### Breaking changes

- Requires `felectronic_dnie_platform_interface` 2.0.0. `FelectronicDnieIOS`
  now extends the shared `MethodChannelFelectronicDnie`.

### Fixed

- 1.0.0 could not link: the j2objc runtime it needs was never shipped. The
  podspec now downloads it on the first `pod install` from the GitHub release
  `j2objc-jre-3.0.0`, verifies it against a pinned SHA-256 before extracting
  anything, and reuses it afterwards. `FELECTRONIC_JRE_URL` points it at a
  mirror.
- Apps building with Swift Package Manager, the default since Flutter 3.47,
  failed: the plugin shipped a template `Package.swift` that SPM cannot build.
  Without it, Flutter builds this plugin through CocoaPods automatically.
- `stopSign()` dropped the pending completions without calling them and left
  the NFC session running. It now fails every pending call with
  `DnieCancelledError` and ends the session.
- The podspec declared a BSD license; the package is MIT.

## 1.0.0

- iOS implementation of DNIe NFC operations via CoreNFC and jmulticard.
- SIGN and AUTH certificate alias selection through the full NFC chain.
- PKCS#1 local signing with SHA-512.
- Card probe via ISO 7816 historical bytes without CAN/PIN.
- Certificate details parsing via SecCertificate APIs.
- Personal data extraction from certificate subject DN.
- PIN retry count parsing from NSError descriptions.
- NFC availability check via NFCTagReaderSession.readingAvailable.
