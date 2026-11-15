# felectronic_dnie_platform_interface

[![pub package](https://img.shields.io/pub/v/felectronic_dnie_platform_interface.svg)](https://pub.dev/packages/felectronic_dnie_platform_interface)

A common platform interface for the [`felectronic_dnie`](https://github.com/Crdzbird/spanishgov_toolkits/tree/master/felectronic_dnie) plugin.

This interface allows platform-specific implementations of the `felectronic_dnie`
plugin, as well as the plugin itself, to ensure they are implementing the same interface.

## Usage

To implement a new platform-specific implementation of `felectronic_dnie`, extend
`FelectronicDniePlatform` with an implementation that performs the platform-specific behavior.

`sign` must sign on the device and return the raw PKCS#1 v1.5 signature
(SHA-512 with RSA) with the certificate as standard Base64 DER. `signCades`
returns CAdES through the remote three-phase service, or throws
`DnieUnsupportedError` where a platform does not offer it.
