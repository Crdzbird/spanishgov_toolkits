import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:felectronic_dnie_platform_interface/src/mappers/card_probe_message_mapper.dart';
import 'package:felectronic_dnie_platform_interface/src/mappers/certificate_details_message_mapper.dart';
import 'package:felectronic_dnie_platform_interface/src/mappers/nfc_status_message_mapper.dart';
import 'package:felectronic_dnie_platform_interface/src/mappers/personal_data_message_mapper.dart';
import 'package:felectronic_dnie_platform_interface/src/mappers/signed_data_message_mapper.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

/// An implementation of [FelectronicDniePlatform] that uses Pigeon-generated
/// type-safe bindings to communicate with the native platform.
///
/// The Android and iOS plugins share one Pigeon API, so both extend this
/// class and only register themselves.
class MethodChannelFelectronicDnie extends FelectronicDniePlatform {
  /// The Pigeon-generated host API used to communicate with native code.
  @visibleForTesting
  FelectronicDnieHostApi api = FelectronicDnieHostApi();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw DnieError.fromPlatformException(e);
    }
  }

  @override
  Future<SignedData> sign({
    required Uint8List data,
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) => _guard(
    () async => (await api.sign(
      data,
      can,
      pin,
      timeout,
      certificateType.value,
    )).toModel(),
  );

  @override
  Future<void> stopSign() => _guard(api.stopSign);

  @override
  Future<SignedData> readCertificate({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) => _guard(
    () async => (await api.readCertificate(
      can,
      pin,
      timeout,
      certificateType.value,
    )).toModel(),
  );

  @override
  Future<CardProbeResult> probeCard({int timeout = 30}) =>
      _guard(() async => (await api.probeCard(timeout)).toModel());

  @override
  Future<CertificateInfo> readCertificateDetails({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) => _guard(
    () async => (await api.readCertificateDetails(
      can,
      pin,
      timeout,
      certificateType.value,
    )).toModel(),
  );

  @override
  Future<PersonalData> readPersonalData({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) => _guard(
    () async => (await api.readPersonalData(
      can,
      pin,
      timeout,
      certificateType.value,
    )).toModel(),
  );

  @override
  Future<void> verifyPin({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) => _guard(() => api.verifyPin(can, pin, timeout, certificateType.value));

  @override
  Future<NfcStatus> checkNfcAvailability() =>
      _guard(() async => (await api.checkNfcAvailability()).toModel());
}
