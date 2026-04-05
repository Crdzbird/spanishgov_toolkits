# felectronic_certificates_platform_interface

A common platform interface for the [`felectronic_certificates`](https://github.com/nicoacevedor/felectronic_dnie/tree/master/felectronic_certificates) plugin.

This interface allows platform-specific implementations of the `felectronic_certificates`
plugin, as well as the plugin itself, to ensure they are implementing the same interface.

## Usage

To implement a new platform-specific implementation of `felectronic_certificates`, extend
`FelectronicCertificatesPlatform` with an implementation that performs the
platform-specific behavior.
