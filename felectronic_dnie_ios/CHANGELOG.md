# Changelog

## 1.0.0

- iOS implementation of DNIe NFC operations via CoreNFC and jmulticard.
- SIGN and AUTH certificate alias selection through the full NFC chain.
- PKCS#1 local signing with SHA-512.
- Card probe via ISO 7816 historical bytes without CAN/PIN.
- Certificate details parsing via SecCertificate APIs.
- Personal data extraction from certificate subject DN.
- PIN retry count parsing from NSError descriptions.
- NFC availability check via NFCTagReaderSession.readingAvailable.
