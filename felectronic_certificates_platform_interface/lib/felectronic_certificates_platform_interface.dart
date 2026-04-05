import 'dart:typed_data';

import 'package:felectronic_certificates_platform_interface/src/errors/certificate_error.dart';
import 'package:felectronic_certificates_platform_interface/src/method_channel_felectronic_certificates.dart';
import 'package:felectronic_certificates_platform_interface/src/models/cert_sign_algorithm.dart';
import 'package:felectronic_certificates_platform_interface/src/models/device_certificate.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

export 'package:felectronic_x509/felectronic_x509.dart';

export 'src/errors/certificate_error.dart';
export 'src/generated/messages.g.dart';
export 'src/models/cert_key_usage.dart';
export 'src/models/cert_sign_algorithm.dart';
export 'src/models/device_certificate.dart';
export 'src/utils/certificate_extensions.dart';

/// {@template felectronic_certificates_platform}
/// The interface that implementations of felectronic_certificates must
/// implement.
///
/// Platform implementations should extend this class
/// rather than implement it as `FelectronicCertificates`.
///
/// Extending this class (using `extends`) ensures that the subclass will get
/// the default implementation, while platform implementations that
/// `implements` this interface will be broken by newly added
/// [FelectronicCertificatesPlatform] methods.
/// {@endtemplate}
abstract class FelectronicCertificatesPlatform extends PlatformInterface {
  /// {@macro felectronic_certificates_platform}
  FelectronicCertificatesPlatform() : super(token: _token);

  static final Object _token = Object();

  static FelectronicCertificatesPlatform _instance =
      MethodChannelFelectronicCertificates();

  /// The default instance of [FelectronicCertificatesPlatform] to use.
  ///
  /// Defaults to [MethodChannelFelectronicCertificates].
  static FelectronicCertificatesPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own
  /// platform-specific class that extends [FelectronicCertificatesPlatform]
  /// when they register themselves.
  static set instance(FelectronicCertificatesPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Returns all certificates stored on the device.
  Future<List<DeviceCertificate>> getAllCertificates();

  /// Returns the currently selected default certificate, if any.
  Future<DeviceCertificate?> getDefaultCertificate();

  /// Opens a native certificate picker and returns the selected certificate.
  Future<DeviceCertificate?> selectDefaultCertificate();

  /// Sets the default certificate by its serial number.
  Future<void> setDefaultCertificateBySerialNumber(String serialNumber);

  /// Clears the default certificate selection.
  Future<void> clearDefaultCertificate();

  /// Signs [data] using the default certificate's private key.
  ///
  /// Uses [algorithm] to determine the signing algorithm
  /// (defaults to [CertSignAlgorithm.sha256rsa]).
  ///
  /// Throws [CertificateError] on failure.
  Future<Uint8List> signWithDefaultCertificate(
    Uint8List data, {
    CertSignAlgorithm algorithm = CertSignAlgorithm.sha256rsa,
  });

  /// Imports a PKCS#12 (.p12/.pfx) file into the device keystore.
  ///
  /// [password] is optional if the file is not encrypted.
  /// [alias] is an optional label for the imported certificate.
  Future<void> importCertificate(
    Uint8List pkcs12Data, {
    String? password,
    String? alias,
  });

  /// Deletes the currently selected default certificate.
  Future<void> deleteDefaultCertificate();

  /// Deletes a certificate identified by its serial number.
  Future<void> deleteCertificateBySerialNumber(String serialNumber);
}
