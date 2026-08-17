import 'dart:convert';
import 'dart:typed_data';

import 'package:felectronic_certificates/src/advanced_signature.dart';
import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';
import 'package:felectronic_triphase/felectronic_triphase.dart';

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
  ///
  /// With no [format], this produces a bare PKCS#1 signature over [data] and
  /// nothing leaves the device.
  ///
  /// With a [format], it produces an advanced signature — CAdES, PAdES or
  /// XAdES — using the @firma three-phase protocol. **That sends [data] to
  /// the signing service.** The private key never leaves the device, but the
  /// document does; that is inherent to how the envelopes are built, not a
  /// choice this package makes. Callers handling confidential documents
  /// should know this before passing a format.
  ///
  /// ```dart
  /// // Raw PKCS#1 — offline, nothing transmitted.
  /// final raw = await session.sign(bytes);
  ///
  /// // A PAdES envelope — the document is sent to the service.
  /// final pades = await session.sign(bytes, format: SignatureFormat.pades);
  /// ```
  ///
  /// Throws [TriphaseException] when a format is given and the service call
  /// fails; the subclass says whether it was the transport, the service or a
  /// malformed response.
  Future<Uint8List> sign(
    Uint8List data, {
    CertSignAlgorithm algorithm = CertSignAlgorithm.sha256rsa,
    SignatureFormat? format,
    TriphaseTransport? transport,
    Uri? serviceUrl,
    String extraParams = '',
  }) {
    if (format == null) {
      return _platform.signWithDefaultCertificate(data, algorithm: algorithm);
    }
    if (transport == null) {
      throw ArgumentError.value(
        transport,
        'transport',
        'an advanced signature needs a transport: this package performs no '
            'network I/O of its own, so the caller supplies the HTTP client',
      );
    }
    return TriphaseClient(transport: transport, serviceUrl: serviceUrl).sign(
      document: data,
      certificateBase64: base64.encode(certificate.encoded),
      format: format,
      algorithm: algorithm.triphaseAlgorithm,
      extraParams: extraParams,
      // The service asks for a signature over the payload it returns, under
      // the same algorithm — which is exactly what the platform's signing
      // entry point does.
      signPkcs1: (payload) =>
          _platform.signWithDefaultCertificate(payload, algorithm: algorithm),
    );
  }

  /// Deletes this certificate from the device keystore.
  Future<void> delete() =>
      _platform.deleteCertificateBySerialNumber(certificate.serialNumber);

  /// Clears the default selection (does not delete the certificate).
  Future<void> clear() => _platform.clearDefaultCertificate();
}
