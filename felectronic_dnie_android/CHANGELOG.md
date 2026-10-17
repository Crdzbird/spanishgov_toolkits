# Changelog

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
