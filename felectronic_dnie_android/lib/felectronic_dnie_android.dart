import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Android implementation of [FelectronicDniePlatform].
class FelectronicDnieAndroid extends FelectronicDniePlatform {
  /// The Pigeon-generated host API used to communicate with native code.
  @visibleForTesting
  FelectronicDnieHostApi api = FelectronicDnieHostApi();

  /// Registers this class as the default instance of
  /// [FelectronicDniePlatform].
  static void registerWith() {
    FelectronicDniePlatform.instance = FelectronicDnieAndroid();
  }

  @override
  Future<SignedData> sign({
    required Uint8List data,
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) async {
    try {
      final result = await api.sign(
        data,
        can,
        pin,
        timeout,
        certificateType.value,
      );
      return _toSignedData(result);
    } on PlatformException catch (e) {
      throw DnieError.fromPlatformException(e);
    }
  }

  @override
  Future<void> stopSign() async {
    try {
      await api.stopSign();
    } on PlatformException catch (e) {
      throw DnieError.fromPlatformException(e);
    }
  }

  @override
  Future<SignedData> readCertificate({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) async {
    try {
      final result = await api.readCertificate(
        can,
        pin,
        timeout,
        certificateType.value,
      );
      return _toSignedData(result);
    } on PlatformException catch (e) {
      throw DnieError.fromPlatformException(e);
    }
  }

  @override
  Future<CardProbeResult> probeCard({int timeout = 30}) async {
    try {
      final result = await api.probeCard(timeout);
      return CardProbeResult(
        isValidDnie: result.isValidDnie,
        atrHex: result.atrHex,
        tagId: result.tagId,
      );
    } on PlatformException catch (e) {
      throw DnieError.fromPlatformException(e);
    }
  }

  @override
  Future<CertificateInfo> readCertificateDetails({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) async {
    try {
      final result = await api.readCertificateDetails(
        can,
        pin,
        timeout,
        certificateType.value,
      );
      return CertificateInfo(
        subjectCommonName: result.subjectCommonName,
        subjectSerialNumber: result.subjectSerialNumber,
        issuerCommonName: result.issuerCommonName,
        issuerOrganization: result.issuerOrganization,
        notValidBefore:
            DateTime.fromMillisecondsSinceEpoch(result.notValidBefore),
        notValidAfter:
            DateTime.fromMillisecondsSinceEpoch(result.notValidAfter),
        serialNumber: result.serialNumber,
        isCurrentlyValid: result.isCurrentlyValid,
      );
    } on PlatformException catch (e) {
      throw DnieError.fromPlatformException(e);
    }
  }

  @override
  Future<PersonalData> readPersonalData({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) async {
    try {
      final result = await api.readPersonalData(
        can,
        pin,
        timeout,
        certificateType.value,
      );
      return PersonalData(
        fullName: result.fullName,
        givenName: result.givenName,
        surnames: result.surnames,
        nif: result.nif,
        country: result.country,
        certificateType: result.certificateType,
      );
    } on PlatformException catch (e) {
      throw DnieError.fromPlatformException(e);
    }
  }

  @override
  Future<void> verifyPin({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) async {
    try {
      await api.verifyPin(can, pin, timeout, certificateType.value);
    } on PlatformException catch (e) {
      throw DnieError.fromPlatformException(e);
    }
  }

  @override
  Future<NfcStatus> checkNfcAvailability() async {
    try {
      final result = await api.checkNfcAvailability();
      return NfcStatus(
        isAvailable: result.isAvailable,
        isEnabled: result.isEnabled,
      );
    } on PlatformException catch (e) {
      throw DnieError.fromPlatformException(e);
    }
  }

  SignedData _toSignedData(DnieSignedDataMessage message) => SignedData(
        signedData: message.signedData,
        signedDataBase64: message.signedDataBase64,
        certificate: message.certificate,
      );
}
