import 'dart:typed_data';

import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';

FelectronicDniePlatform get _platform => FelectronicDniePlatform.instance;

/// Signs [data] using the DNIe private key via NFC.
Future<SignedData> sign({
  required Uint8List data,
  required String can,
  required String pin,
  Duration timeout = dnieDefaultTimeout,
  DnieCertificateType certificateType = DnieCertificateType.sign,
}) => _platform.sign(
  data: data,
  can: can,
  pin: pin,
  timeout: timeout,
  certificateType: certificateType,
);

/// Stops an in-progress NFC operation.
Future<void> stopSign() => _platform.stopSign();

/// Reads a certificate from the DNIe without signing data.
Future<SignedData> readCertificate({
  required String can,
  required String pin,
  Duration timeout = dnieDefaultTimeout,
  DnieCertificateType certificateType = DnieCertificateType.sign,
}) => _platform.readCertificate(
  can: can,
  pin: pin,
  timeout: timeout,
  certificateType: certificateType,
);

/// Probes an NFC card to check if it is a valid Spanish DNIe.
Future<CardProbeResult> probeCard({Duration timeout = dnieDefaultTimeout}) =>
    _platform.probeCard(timeout: timeout);

/// Reads and parses X.509 certificate details from the DNIe.
Future<CertificateInfo> readCertificateDetails({
  required String can,
  required String pin,
  Duration timeout = dnieDefaultTimeout,
  DnieCertificateType certificateType = DnieCertificateType.sign,
}) => _platform.readCertificateDetails(
  can: can,
  pin: pin,
  timeout: timeout,
  certificateType: certificateType,
);

/// Reads personal data from the DNIe certificate subject DN.
Future<PersonalData> readPersonalData({
  required String can,
  required String pin,
  Duration timeout = dnieDefaultTimeout,
  DnieCertificateType certificateType = DnieCertificateType.sign,
}) => _platform.readPersonalData(
  can: can,
  pin: pin,
  timeout: timeout,
  certificateType: certificateType,
);

/// Verifies PIN and CAN credentials without signing.
Future<void> verifyPin({
  required String can,
  required String pin,
  Duration timeout = dnieDefaultTimeout,
  DnieCertificateType certificateType = DnieCertificateType.sign,
}) => _platform.verifyPin(
  can: can,
  pin: pin,
  timeout: timeout,
  certificateType: certificateType,
);

/// Checks if NFC hardware is available and enabled on the device.
Future<NfcStatus> checkNfcAvailability() => _platform.checkNfcAvailability();
