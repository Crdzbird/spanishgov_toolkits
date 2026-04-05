import 'dart:typed_data';

import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';

/// {@template certificate_session}
/// A convenience wrapper around a selected device certificate.
///
/// Provides shorthand methods for signing and management without
/// repeating certificate lookup logic.
///
/// ```dart
/// // From picker
/// final session = await CertificateSession.select();
/// if (session != null) {
///   final sig = await session.sign(myData);
/// }
///
/// // From existing default
/// final session = await CertificateSession.fromDefault();
/// ```
/// {@endtemplate}
class CertificateSession {
  CertificateSession._(this.certificate);

  /// The selected certificate.
  final DeviceCertificate certificate;

  static FelectronicCertificatesPlatform get _platform =>
      FelectronicCertificatesPlatform.instance;

  /// Opens the native certificate picker and creates a session
  /// from the selected certificate.
  ///
  /// Returns `null` if the user cancels the picker.
  static Future<CertificateSession?> select() async {
    final cert = await _platform.selectDefaultCertificate();
    return cert == null ? null : CertificateSession._(cert);
  }

  /// Creates a session from the currently selected default certificate.
  ///
  /// Returns `null` if no default certificate is set.
  static Future<CertificateSession?> fromDefault() async {
    final cert = await _platform.getDefaultCertificate();
    return cert == null ? null : CertificateSession._(cert);
  }

  /// Signs [data] using this certificate's private key.
  Future<Uint8List> sign(
    Uint8List data, {
    CertSignAlgorithm algorithm = CertSignAlgorithm.sha256rsa,
  }) =>
      _platform.signWithDefaultCertificate(data, algorithm: algorithm);

  /// Deletes this certificate from the device keystore.
  Future<void> delete() =>
      _platform.deleteCertificateBySerialNumber(certificate.serialNumber);

  /// Clears the default selection (does not delete the certificate).
  Future<void> clear() => _platform.clearDefaultCertificate();
}
