import 'dart:convert';
import 'dart:typed_data';

import 'package:felectronic_dnie/src/dnie_operations.dart' as dnie;
import 'package:felectronic_dnie/src/workflows/dnie_identity.dart';
import 'package:felectronic_dnie/src/workflows/dnie_readiness.dart';
import 'package:felectronic_dnie/src/workflows/dnie_workflows.dart'
    as workflows;
import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';

part 'dnie_session_shorthand.dart';

/// {@template dnie_session}
/// A session that stores CAN and PIN once, providing shorthand
/// methods for all DNIe operations without repeating credentials.
///
/// ```dart
/// final session = DnieSession(can: '123456', pin: 'mySecurePin');
/// final signed = await session.signText('Hello, DNIe!');
/// final identity = await session.readFullIdentity();
/// final login = await session.auth.readCertificate();
/// await session.stop();
/// ```
///
/// Validates CAN and PIN format on construction.
/// {@endtemplate}
final class DnieSession {
  /// {@macro dnie_session}
  ///
  /// Throws [ArgumentError] if [can] or [pin] format is invalid.
  factory DnieSession({
    required String can,
    required String pin,
    DnieCertificateType certificateType = DnieCertificateType.sign,
    Duration timeout = dnieDefaultTimeout,
  }) {
    final error = can.validateCan() ?? pin.validatePin();
    if (error != null) throw ArgumentError(error.message);
    return DnieSession._(can, pin, certificateType, timeout);
  }

  const DnieSession._(this._can, this._pin, this.certificateType, this.timeout);

  final String _can;
  final String _pin;

  /// Which certificate to use for operations.
  final DnieCertificateType certificateType;

  /// How long to wait for a card.
  final Duration timeout;

  /// Signs [data] using the DNIe.
  Future<SignedData> sign(Uint8List data) => dnie.sign(
    data: data,
    can: _can,
    pin: _pin,
    timeout: timeout,
    certificateType: certificateType,
  );

  /// Reads the raw certificate.
  Future<SignedData> readCertificate() => dnie.readCertificate(
    can: _can,
    pin: _pin,
    timeout: timeout,
    certificateType: certificateType,
  );

  /// Reads parsed certificate details.
  Future<CertificateInfo> certificateDetails() => dnie.readCertificateDetails(
    can: _can,
    pin: _pin,
    timeout: timeout,
    certificateType: certificateType,
  );

  /// Reads personal data from the certificate.
  Future<PersonalData> personalData() => dnie.readPersonalData(
    can: _can,
    pin: _pin,
    timeout: timeout,
    certificateType: certificateType,
  );

  /// Verifies that CAN and PIN are correct.
  Future<void> verifyCredentials() => dnie.verifyPin(
    can: _can,
    pin: _pin,
    timeout: timeout,
    certificateType: certificateType,
  );

  /// Stops an in-progress NFC operation.
  Future<void> stop() => dnie.stopSign();
}
