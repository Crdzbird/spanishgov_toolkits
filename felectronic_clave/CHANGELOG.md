# Changelog

## 1.0.0

- OAuth/OIDC authentication via ClaveRepository with 5 Clave methods.
- Clave Movil flow: notification code creation and polling validation.
- ClaveMobilePoller stream for declarative polling.
- Token management: store, refresh, validate, backup/restore for LOA elevation.
- DocumentValidator for DNI/NIE format and checksum validation.
- ClaveValidationError enum for document and contrast validation.
- String extensions: isValidDni, isValidNie, validateDocument(), validateContrast().
- ClaveAuthResultX, ClaveMobileSessionX, ClaveConfigX convenience extensions.
- JwtParser for lightweight JWT payload extraction.
- Typed error hierarchy with 8 error subclasses.
