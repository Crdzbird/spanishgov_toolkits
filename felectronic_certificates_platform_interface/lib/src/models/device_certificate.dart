import 'dart:typed_data';

import 'package:felectronic_certificates_platform_interface/src/models/cert_key_usage.dart';
import 'package:flutter/foundation.dart' show immutable;

/// {@template device_certificate}
/// Represents a certificate stored on the device (keychain / keystore).
/// {@endtemplate}
@immutable
class DeviceCertificate {
  /// {@macro device_certificate}
  const DeviceCertificate({
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

  /// Optional alias / label.
  final String? alias;

  /// Holder (subject) common name.
  final String holderName;

  /// Issuer common name.
  final String issuerName;

  /// Certificate expiration date.
  final DateTime expirationDate;

  /// Key usage flags for this certificate.
  final List<CertKeyUsage> usages;

  /// DER-encoded certificate bytes.
  final Uint8List encoded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceCertificate &&
          runtimeType == other.runtimeType &&
          serialNumber == other.serialNumber;

  @override
  int get hashCode => serialNumber.hashCode;

  @override
  String toString() =>
      'DeviceCertificate(serialNumber: $serialNumber, '
      'holder: $holderName, issuer: $issuerName, '
      'expires: $expirationDate, usages: $usages)';
}
