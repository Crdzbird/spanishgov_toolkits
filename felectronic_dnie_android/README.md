# felectronic_dnie_android

[![pub package](https://img.shields.io/pub/v/felectronic_dnie_android.svg)](https://pub.dev/packages/felectronic_dnie_android)

The Android implementation of [`felectronic_dnie`](https://github.com/Crdzbird/spanishgov_toolkits/tree/master/felectronic_dnie).

## Usage

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin) and
will be automatically included when you depend on `felectronic_dnie`.

## Signing

`sign` reads the card over NFC and signs on the phone with the private key of
the requested certificate. It returns the raw PKCS#1 v1.5 signature, SHA-512
with RSA, and the certificate as standard Base64 DER, the same as iOS, and
makes no network call.

`signCades` is the separate, explicit route to a CAdES signature through the
three-phase protocol: the data and the certificate chain are sent to
`https://firmamovil-appfactory.redsara.es`. Up to 2.x, `sign` did this.
