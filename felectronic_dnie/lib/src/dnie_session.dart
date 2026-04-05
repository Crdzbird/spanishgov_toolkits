import 'dart:typed_data';

import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';

/// {@template dnie_session}
/// A session that stores CAN and PIN once, providing shorthand
/// methods for all DNIe operations without repeating credentials.
///
/// ```dart
/// final session = DnieSession(can: '123456', pin: 'mySecurePin');
/// final signed = await session.sign(data);
/// final identity = await session.readFullIdentity();
/// await session.stop();
/// ```
///
/// Validates CAN and PIN format on construction.
/// {@endtemplate}
class DnieSession {
  /// {@macro dnie_session}
  ///
  /// Throws [ArgumentError] if [can] or [pin] format is invalid.
  DnieSession({
    required String can,
    required String pin,
    this.certificateType = DnieCertificateType.sign,
    this.timeout = 30,
  })  : _can = can.trim(),
        _pin = pin.trim() {
    final canError = _can.validateCan();
    if (canError != null) throw ArgumentError(canError);
    final pinError = _pin.validatePin();
    if (pinError != null) throw ArgumentError(pinError);
  }

  final String _can;
  final String _pin;

  /// Which certificate to use for operations.
  final DnieCertificateType certificateType;

  /// NFC scan timeout in seconds.
  final int timeout;

  FelectronicDniePlatform get _platform => FelectronicDniePlatform.instance;

  /// Signs [data] using the DNIe.
  Future<SignedData> sign(Uint8List data) => _platform.sign(
        data: data,
        can: _can,
        pin: _pin,
        timeout: timeout,
        certificateType: certificateType,
      );

  /// Reads the raw certificate.
  Future<SignedData> readCertificate() => _platform.readCertificate(
        can: _can,
        pin: _pin,
        timeout: timeout,
        certificateType: certificateType,
      );

  /// Reads parsed certificate details.
  Future<CertificateInfo> certificateDetails() =>
      _platform.readCertificateDetails(
        can: _can,
        pin: _pin,
        timeout: timeout,
        certificateType: certificateType,
      );

  /// Reads personal data from the certificate.
  Future<PersonalData> personalData() => _platform.readPersonalData(
        can: _can,
        pin: _pin,
        timeout: timeout,
        certificateType: certificateType,
      );

  /// Verifies that CAN and PIN are correct.
  Future<void> verifyCredentials() => _platform.verifyPin(
        can: _can,
        pin: _pin,
        timeout: timeout,
        certificateType: certificateType,
      );

  /// Stops an in-progress NFC operation.
  Future<void> stop() => _platform.stopSign();
}
