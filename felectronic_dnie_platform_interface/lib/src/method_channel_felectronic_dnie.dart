import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

/// An implementation of [FelectronicDniePlatform] that uses Pigeon-generated
/// type-safe bindings to communicate with the native platform.
class MethodChannelFelectronicDnie extends FelectronicDniePlatform {
  /// The Pigeon-generated host API used to communicate with native code.
  @visibleForTesting
  FelectronicDnieHostApi api = FelectronicDnieHostApi();

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
      return _toCertificateInfo(result);
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

  CertificateInfo _toCertificateInfo(DnieCertificateDetailsMessage msg) =>
      CertificateInfo(
        subjectCommonName: msg.subjectCommonName,
        subjectSerialNumber: msg.subjectSerialNumber,
        issuerCommonName: msg.issuerCommonName,
        issuerOrganization: msg.issuerOrganization,
        notValidBefore:
            DateTime.fromMillisecondsSinceEpoch(msg.notValidBefore),
        notValidAfter:
            DateTime.fromMillisecondsSinceEpoch(msg.notValidAfter),
        serialNumber: msg.serialNumber,
        isCurrentlyValid: msg.isCurrentlyValid,
      );
}
