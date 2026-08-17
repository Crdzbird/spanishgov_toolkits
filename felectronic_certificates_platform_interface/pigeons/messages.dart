import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/messages.g.dart',
    kotlinOut:
        '../felectronic_certificates_android/android/src/main/kotlin/es/gob/electronic_certificates/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'es.gob.electronic_certificates'),
    swiftOut:
        '../felectronic_certificates_ios/ios/felectronic_certificates_ios/Sources/felectronic_certificates_ios/Messages.g.swift',
  ),
)
/// Signing algorithms supported for certificate-based signatures.
///
/// Sent as a typed enum rather than a string so an unrecognised value is a
/// deserialisation error at the boundary instead of silently degrading to a
/// default algorithm on the native side.
enum CertSignAlgorithmMessage {
  sha256rsa,
  sha384rsa,
  sha512rsa,
  sha256ec,
  sha384ec,
  sha512ec,
}

/// A device-stored certificate transferred between native and Dart layers.
///
/// Carries only what the platform keystore alone can supply. Everything that
/// can be derived from the certificate itself — subject CN, issuer CN,
/// validity, key usage — is decoded once in Dart from [encoded] by
/// `felectronic_x509`, so Android and iOS cannot report different values for
/// the same certificate.
class DeviceCertificateMessage {
  DeviceCertificateMessage({
    required this.serialNumber,
    required this.encoded,
    this.alias,
  });

  /// Certificate serial number, canonically encoded.
  ///
  /// Lowercase hex of the serial's magnitude: no DER sign-padding byte, no
  /// leading zeros, and `"0"` for a zero serial. Both platforms must emit
  /// this exact form, and both must compare incoming serials in this form —
  /// it is the keystore lookup key, and values persisted by earlier versions
  /// used platform-specific spellings.
  final String serialNumber;

  /// Keystore label for this certificate, if one was assigned.
  ///
  /// Not part of the certificate — it exists only in the keystore, which is
  /// why it still crosses the boundary.
  final String? alias;

  /// DER-encoded certificate: the source of truth for every other field.
  final Uint8List encoded;
}

/// Host API for device-stored certificate operations, implemented
/// on Android (Kotlin) and iOS (Swift).
@HostApi()
abstract class FelectronicCertificatesHostApi {
  /// Returns all certificates stored on the device.
  @async
  List<DeviceCertificateMessage?> getAllCertificates();

  /// Returns the currently selected default certificate, if any.
  @async
  DeviceCertificateMessage? getDefaultCertificate();

  /// Opens a native certificate picker and returns the selected certificate.
  @async
  DeviceCertificateMessage? selectDefaultCertificate();

  /// Sets the default certificate by its serial number.
  ///
  /// [serialNumber] is compared in canonical form, so serials persisted by
  /// earlier versions still resolve.
  @async
  void setDefaultCertificateBySerialNumber(String serialNumber);

  /// Clears the default certificate selection.
  @async
  void clearDefaultCertificate();

  /// Signs [data] using the default certificate's private key.
  @async
  Uint8List signWithDefaultCertificate(
    Uint8List data,
    CertSignAlgorithmMessage algorithm,
  );

  /// Imports a PKCS#12 (.p12/.pfx) file into the device keystore.
  @async
  void importCertificate(Uint8List pkcs12Data, String? password, String? alias);

  /// Deletes the currently selected default certificate.
  @async
  void deleteDefaultCertificate();

  /// Deletes a certificate identified by its serial number.
  @async
  void deleteCertificateBySerialNumber(String serialNumber);
}
