import 'package:flutter/foundation.dart';

/// {@template certificate_info}
/// Parsed X.509 certificate details from the DNIe.
/// {@endtemplate}
@immutable
final class CertificateInfo {
  /// {@macro certificate_info}
  const factory CertificateInfo({
    required String subjectCommonName,
    required String subjectSerialNumber,
    required String issuerCommonName,
    required String issuerOrganization,
    required DateTime notValidBefore,
    required DateTime notValidAfter,
    required String serialNumber,
    required bool isCurrentlyValid,
  }) = CertificateInfo._;

  const CertificateInfo._({
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

  /// Subject serial number, which is the NIF (e.g. "12345678Z").
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

  /// Whether the certificate was valid when the card was read, as judged by
  /// the device clock on the native side.
  final bool isCurrentlyValid;

  /// Whether [moment] falls within the validity period, bounds included.
  bool isValidAt(DateTime moment) =>
      !moment.isBefore(notValidBefore) && !moment.isAfter(notValidAfter);

  /// Whether the certificate has expired.
  bool get isExpired => DateTime.now().isAfter(notValidAfter);

  /// Whether the certificate is not yet valid.
  bool get isNotYetValid => DateTime.now().isBefore(notValidBefore);

  Record get _fields => (
    subjectCommonName,
    subjectSerialNumber,
    issuerCommonName,
    issuerOrganization,
    notValidBefore,
    notValidAfter,
    serialNumber,
    isCurrentlyValid,
  );

  @override
  bool operator ==(Object other) =>
      other is CertificateInfo && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;

  @override
  String toString() =>
      'CertificateInfo(subject: $subjectCommonName, '
      'nif: $subjectSerialNumber, valid: $isCurrentlyValid, '
      'expires: $notValidAfter)';
}
