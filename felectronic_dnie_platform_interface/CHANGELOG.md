# Changelog

## 1.0.0

- Pigeon-based type-safe platform interface for DNIe NFC operations.
- Sign data with SIGN or AUTH certificate selection.
- Read raw certificate, certificate details, and personal data.
- Card probe (no PIN required) with ATR and tag ID.
- PIN verification without signing.
- NFC hardware availability check.
- Typed error hierarchy with 14 error subclasses.
- Input validators for CAN and PIN with enum-based error codes.
- Model extensions for certificate expiry, NFC status, and signed data.
- X.509 certificate parsing via felectronic_x509 integration.
