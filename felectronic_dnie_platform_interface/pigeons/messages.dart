import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/messages.g.dart',
    kotlinOut:
        '../felectronic_dnie_android/android/src/main/kotlin/es/gob/electronic_dnie/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'es.gob.electronic_dnie'),
    swiftOut:
        '../felectronic_dnie_ios/ios/felectronic_dnie_ios/Sources/felectronic_dnie_ios/Messages.g.swift',
  ),
)

/// Result of a successful DNIe signing or certificate-reading operation.
class DnieSignedDataMessage {
  DnieSignedDataMessage({
    required this.signedData,
    required this.signedDataBase64,
    required this.certificate,
  });

  final Uint8List signedData;
  final String signedDataBase64;
  final String certificate;
}

/// Result of a card probe operation (no PIN required).
class DnieCardProbeMessage {
  DnieCardProbeMessage({
    required this.isValidDnie,
    required this.atrHex,
    required this.tagId,
  });

  /// Whether the detected card is a valid Spanish DNIe.
  final bool isValidDnie;

  /// Historical bytes from the card as a hex string.
  final String atrHex;

  /// Tag UID / identifier as a hex string.
  final String tagId;
}

/// Parsed X.509 certificate details from the DNIe.
class DnieCertificateDetailsMessage {
  DnieCertificateDetailsMessage({
    required this.subjectCommonName,
    required this.subjectSerialNumber,
    required this.issuerCommonName,
    required this.issuerOrganization,
    required this.notValidBefore,
    required this.notValidAfter,
    required this.serialNumber,
    required this.isCurrentlyValid,
  });

  /// Subject common name (e.g. "APELLIDO1 APELLIDO2, NOMBRE (FIRMA)").
  final String subjectCommonName;

  /// Subject serial number (NIF, e.g. "12345678Z").
  final String subjectSerialNumber;

  /// Issuer common name.
  final String issuerCommonName;

  /// Issuer organization.
  final String issuerOrganization;

  /// Certificate validity start as epoch milliseconds.
  final int notValidBefore;

  /// Certificate validity end as epoch milliseconds.
  final int notValidAfter;

  /// Certificate serial number as hex string.
  final String serialNumber;

  /// Whether the certificate is currently valid.
  final bool isCurrentlyValid;
}

/// Personal data extracted from the DNIe certificate subject DN.
class DniePersonalDataMessage {
  DniePersonalDataMessage({
    required this.fullName,
    required this.givenName,
    required this.surnames,
    required this.nif,
    required this.country,
    required this.certificateType,
  });

  /// Full name (given name + surnames).
  final String fullName;

  /// Given name / first name.
  final String givenName;

  /// Surnames (first + second).
  final String surnames;

  /// NIF (Numero de Identificacion Fiscal).
  final String nif;

  /// Country code (e.g. "ES").
  final String country;

  /// Certificate type (e.g. "FIRMA", "AUTENTICACION").
  final String certificateType;
}

/// NFC hardware status of the device.
class DnieNfcStatusMessage {
  DnieNfcStatusMessage({
    required this.isAvailable,
    required this.isEnabled,
  });

  /// Whether the device has NFC hardware.
  final bool isAvailable;

  /// Whether NFC is enabled in system settings.
  final bool isEnabled;
}

/// Host API for DNIe NFC operations, implemented on Android (Kotlin)
/// and iOS (Swift).
@HostApi()
abstract class FelectronicDnieHostApi {
  /// Signs [data] using the DNIe private key via NFC.
  ///
  /// [certificateType] selects which certificate to use: `'SIGN'` or `'AUTH'`.
  @async
  DnieSignedDataMessage sign(
    Uint8List data,
    String can,
    String pin,
    int timeout,
    String certificateType,
  );

  /// Stops an in-progress NFC signing operation.
  @async
  void stopSign();

  /// Reads the certificate from the DNIe without signing data.
  ///
  /// [certificateType] selects which certificate to read: `'SIGN'` or `'AUTH'`.
  @async
  DnieSignedDataMessage readCertificate(
    String can,
    String pin,
    int timeout,
    String certificateType,
  );

  /// Probes an NFC card to check if it is a valid DNIe.
  /// No CAN or PIN required.
  @async
  DnieCardProbeMessage probeCard(int timeout);

  /// Reads and parses X.509 certificate details from the DNIe.
  ///
  /// [certificateType] selects which certificate: `'SIGN'` or `'AUTH'`.
  @async
  DnieCertificateDetailsMessage readCertificateDetails(
    String can,
    String pin,
    int timeout,
    String certificateType,
  );

  /// Reads personal data from the DNIe certificate subject DN.
  ///
  /// [certificateType] selects which certificate: `'SIGN'` or `'AUTH'`.
  @async
  DniePersonalDataMessage readPersonalData(
    String can,
    String pin,
    int timeout,
    String certificateType,
  );

  /// Verifies PIN and CAN credentials without signing.
  ///
  /// [certificateType] selects which certificate: `'SIGN'` or `'AUTH'`.
  @async
  void verifyPin(
    String can,
    String pin,
    int timeout,
    String certificateType,
  );

  /// Checks if NFC hardware is available and enabled.
  @async
  DnieNfcStatusMessage checkNfcAvailability();
}
