# Changelog

## 3.0.0

### Breaking changes

- `sign` no longer goes through the remote three-phase service. It reads the
  card over NFC and signs the data on the phone with the private key of the
  requested certificate, returning the raw PKCS#1 v1.5 signature (SHA-512 with
  RSA) and the certificate as standard Base64 DER, the same shape iOS returns.
  Nothing is sent over the network. Before, the data and the certificate chain
  went to `https://firmamovil-appfactory.redsara.es` and the result was CAdES.
- With NFC switched off, or on a device without NFC, every operation fails at
  once with `DSNfcUnavailableException` (`DnieNfcUnavailableError`) instead of
  waiting for the timeout.

### Added

- `signCades`, the three-phase CAdES signature `sign` used to make.

### Fixed

- The on-device signer `sign` now uses, previously unused, computed the
  signature twice, so the Base64 it returned was the signature of empty input,
  and that Base64 carried line breaks. It signs once and uses standard Base64
  on one line.

## 2.0.0

### Breaking changes

- Requires `felectronic_dnie_platform_interface` 2.0.0. `FelectronicDnieAndroid`
  now extends the shared `MethodChannelFelectronicDnie`.

### Fixed

- The scan timeout was read as milliseconds, so the default 30 became a
  three second window, and the timer kept running after the card was found,
  cutting off any read or signature that took longer. It is now seconds, and
  it stops once a card is detected.
- `probeCard` reported a real DNIe as "not a DNIe": it looked for the DNIe
  marker in the wrong bytes. It now reads the Type B application data.
- `stopSign()` left the waiting operation pending forever; it now fails it with
  `DnieCancelledError`. A new scan started over an old one does the same to the
  old one, instead of orphaning it.
- A card already on the phone could be detected before the timeout timer
  started, and the late timer then switched reader mode off mid-read.
- `sign` leaves reader mode when it finishes.

### Changed

- Reader mode also polls ISO 14443 Type A and skips the NDEF check, so a bank
  card shows up as "not a DNIe", a quick way to confirm NFC works.

## 1.0.0

- Android implementation of DNIe NFC operations via jmulticard.
- SIGN and AUTH certificate selection support.
- Three-phase signing with remote ADESP server.
- Card probe via IsoDep without requiring CAN/PIN.
- Certificate details and personal data extraction from X.509 subject DN.
- PIN retry count extraction from BadPinException.
- NFC availability check via NfcAdapter.
