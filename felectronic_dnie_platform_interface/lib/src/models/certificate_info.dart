import 'package:flutter/foundation.dart';

/// {@template certificate_info}
/// Parsed X.509 certificate details from the DNIe.
/// {@endtemplate}
@immutable
class CertificateInfo {
  /// {@macro certificate_info}
  const CertificateInfo({
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

  /// Subject serial number — the NIF (e.g. "12345678Z").
  final String subjectSerialNumber;

  /// Issuer common name.
  final String issuerCommonName;

  /// Issuer organization.
  final String issuerOrganization;

  /// Certificate validity start date.
  final DateTime notValidBefore;

  /// Certificate validity end date.
  final DateTime notValidAfter;

  /// Certificate serial number as hex string.
  final String serialNumber;

  /// Whether the certificate is currently valid.
  final bool isCurrentlyValid;

  /// Whether the certificate has expired.
  bool get isExpired => DateTime.now().isAfter(notValidAfter);

  /// Whether the certificate is not yet valid.
  bool get isNotYetValid => DateTime.now().isBefore(notValidBefore);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CertificateInfo &&
          other.subjectCommonName == subjectCommonName &&
          other.subjectSerialNumber == subjectSerialNumber &&
          other.serialNumber == serialNumber;

  @override
  int get hashCode =>
      Object.hash(subjectCommonName, subjectSerialNumber, serialNumber);

  @override
  String toString() => 'CertificateInfo('
      'subject: $subjectCommonName, '
      'nif: $subjectSerialNumber, '
      'valid: $isCurrentlyValid, '
      'expires: $notValidAfter'
      ')';
}
