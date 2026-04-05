# felectronic_dnie_platform_interface

A common platform interface for the [`felectronic_dnie`](https://github.com/nicoacevedor/felectronic_dnie/tree/master/felectronic_dnie) plugin.

This interface allows platform-specific implementations of the `felectronic_dnie`
plugin, as well as the plugin itself, to ensure they are implementing the same interface.

## Usage

To implement a new platform-specific implementation of `felectronic_dnie`, extend
`FelectronicDniePlatform` with an implementation that performs the platform-specific behavior.
