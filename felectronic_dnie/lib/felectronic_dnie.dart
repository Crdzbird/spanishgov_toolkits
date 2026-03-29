import 'dart:typed_data';

import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';

export 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart'
    show
        CardProbeResult,
        CertificateInfo,
        DnieCardTagError,
        DnieCertificateType,
        DnieConnectionError,
        DnieDamagedError,
        DnieError,
        DnieExpiredCertificateError,
        DnieLockedPinError,
        DnieNotDnieError,
        DniePrivateKeyError,
        DnieProviderError,
        DnieSigningError,
        DnieTimeoutError,
        DnieUnderageError,
        DnieUnknownError,
        DnieWrongCanError,
        DnieWrongPinError,
        NfcStatus,
        PersonalData,
        SignedData;

FelectronicDniePlatform get _platform => FelectronicDniePlatform.instance;

/// {@template felectronic_dnie}
/// Flutter plugin for reading and signing with the Spanish electronic DNIe
/// (Documento Nacional de Identidad electrónico) via NFC.
///
/// ```dart
/// final result = await sign(
///   data: utf8.encode('Hello, DNIe!'),
///   can: '123456',
///   pin: 'mySecurePin',
/// );
/// print(result.signedDataBase64);
/// ```
/// {@endtemplate}

/// Signs [data] using the DNIe private key via NFC.
///
/// - [data]: The bytes to sign.
/// - [can]: The 6-digit Card Access Number printed on the card.
/// - [pin]: The 8-16 character PIN associated with the card.
/// - [timeout]: NFC scan timeout in seconds (default 30).
/// - [certificateType]: Which certificate to use — [DnieCertificateType.sign]
///   (default) for signatures or [DnieCertificateType.auth] for authentication.
///
/// Returns a [SignedData] with the signature and certificate.
/// Throws a [DnieError] subclass on failure.
Future<SignedData> sign({
  required Uint8List data,
  required String can,
  required String pin,
  int timeout = 30,
  DnieCertificateType certificateType = DnieCertificateType.sign,
}) =>
    _platform.sign(
      data: data,
      can: can,
      pin: pin,
      timeout: timeout,
      certificateType: certificateType,
    );

/// Stops an in-progress NFC signing operation.
Future<void> stopSign() => _platform.stopSign();

/// Reads a certificate from the DNIe without signing data.
///
/// Returns a [SignedData] where [SignedData.certificate] is populated
/// and [SignedData.signedData] is empty.
///
/// Use [certificateType] to select SIGN (default) or AUTH certificate.
Future<SignedData> readCertificate({
  required String can,
  required String pin,
  int timeout = 30,
  DnieCertificateType certificateType = DnieCertificateType.sign,
}) =>
    _platform.readCertificate(
      can: can,
      pin: pin,
      timeout: timeout,
      certificateType: certificateType,
    );

/// Probes an NFC card to check if it is a valid Spanish DNIe.
///
/// No CAN or PIN required. Returns a [CardProbeResult] with card metadata.
/// Throws a [DnieError] subclass on failure.
Future<CardProbeResult> probeCard({int timeout = 30}) =>
    _platform.probeCard(timeout: timeout);

/// Reads and parses X.509 certificate details from the DNIe.
///
/// Returns a [CertificateInfo] with subject, issuer, validity, and serial.
/// Throws a [DnieError] subclass on failure.
///
/// Use [certificateType] to select SIGN (default) or AUTH certificate.
Future<CertificateInfo> readCertificateDetails({
  required String can,
  required String pin,
  int timeout = 30,
  DnieCertificateType certificateType = DnieCertificateType.sign,
}) =>
    _platform.readCertificateDetails(
      can: can,
      pin: pin,
      timeout: timeout,
      certificateType: certificateType,
    );

/// Reads personal data from the DNIe certificate subject DN.
///
/// Returns a [PersonalData] with name, NIF, and certificate type.
/// Throws a [DnieError] subclass on failure.
///
/// Use [certificateType] to select SIGN (default) or AUTH certificate.
Future<PersonalData> readPersonalData({
  required String can,
  required String pin,
  int timeout = 30,
  DnieCertificateType certificateType = DnieCertificateType.sign,
}) =>
    _platform.readPersonalData(
      can: can,
      pin: pin,
      timeout: timeout,
      certificateType: certificateType,
    );

/// Verifies PIN and CAN credentials without signing.
///
/// Completes successfully if credentials are valid.
/// Throws a [DnieError] subclass on failure.
///
/// Use [certificateType] to select which certificate to verify against.
Future<void> verifyPin({
  required String can,
  required String pin,
  int timeout = 30,
  DnieCertificateType certificateType = DnieCertificateType.sign,
}) =>
    _platform.verifyPin(
      can: can,
      pin: pin,
      timeout: timeout,
      certificateType: certificateType,
    );

/// Checks if NFC hardware is available and enabled on the device.
///
/// Returns an [NfcStatus] with [NfcStatus.isAvailable] and
/// [NfcStatus.isEnabled].
Future<NfcStatus> checkNfcAvailability() =>
    _platform.checkNfcAvailability();
