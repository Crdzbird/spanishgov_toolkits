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

/// A device-stored certificate transferred between native and Dart layers.
class DeviceCertificateMessage {
  DeviceCertificateMessage({
    required this.serialNumber,
    required this.holderName,
    required this.issuerName,
    required this.expirationDate,
    required this.usages,
    required this.encoded,
    this.alias,
  });

  /// Certificate serial number (hex string).
  final String serialNumber;

  /// Optional alias / label assigned to the certificate.
  final String? alias;

  /// Holder (subject) common name.
  final String holderName;

  /// Issuer common name.
  final String issuerName;

  /// Expiration date formatted as dd-MM-yyyy.
  final String expirationDate;

  /// Semicolon-separated key usages, e.g. "SIGNING;AUTHENTICATION".
  final String usages;

  /// DER-encoded certificate bytes.
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
  @async
  void setDefaultCertificateBySerialNumber(String serialNumber);

  /// Clears the default certificate selection.
  @async
  void clearDefaultCertificate();

  /// Signs [data] using the default certificate's private key.
  ///
  /// [algorithm] is one of: SHA256RSA, SHA384RSA, SHA512RSA,
  /// SHA256EC, SHA384EC, SHA512EC.
  @async
  Uint8List signWithDefaultCertificate(Uint8List data, String algorithm);

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
