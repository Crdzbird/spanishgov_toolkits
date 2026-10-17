import 'dart:typed_data';

import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:felectronic_dnie_platform_interface/src/mappers/card_probe_message_mapper.dart';
import 'package:felectronic_dnie_platform_interface/src/mappers/certificate_details_message_mapper.dart';
import 'package:felectronic_dnie_platform_interface/src/mappers/dnie_error_mapping.dart';
import 'package:felectronic_dnie_platform_interface/src/mappers/nfc_status_message_mapper.dart';
import 'package:felectronic_dnie_platform_interface/src/mappers/personal_data_message_mapper.dart';
import 'package:felectronic_dnie_platform_interface/src/mappers/signed_data_message_mapper.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// An implementation of [FelectronicDniePlatform] that uses Pigeon-generated
/// type-safe bindings to communicate with the native platform.
///
/// The Android and iOS plugins share one Pigeon API, so both extend this
/// class and only register themselves.
class MethodChannelFelectronicDnie extends FelectronicDniePlatform {
  /// The Pigeon-generated host API used to communicate with native code.
  @visibleForTesting
  FelectronicDnieHostApi api = FelectronicDnieHostApi();

  @override
  Future<SignedData> sign({
    required Uint8List data,
    required String can,
    required String pin,
    Duration timeout = dnieDefaultTimeout,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) => api
      .sign(data, can, pin, timeout.inSeconds, certificateType.value)
      .then((m) => m.toModel())
      .mapDnieErrors();

  @override
  Future<void> stopSign() => api.stopSign().mapDnieErrors();

  @override
  Future<SignedData> readCertificate({
    required String can,
    required String pin,
    Duration timeout = dnieDefaultTimeout,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) => api
      .readCertificate(can, pin, timeout.inSeconds, certificateType.value)
      .then((m) => m.toModel())
      .mapDnieErrors();

  @override
  Future<CardProbeResult> probeCard({Duration timeout = dnieDefaultTimeout}) =>
      api.probeCard(timeout.inSeconds).then((m) => m.toModel()).mapDnieErrors();

  @override
  Future<CertificateInfo> readCertificateDetails({
    required String can,
    required String pin,
    Duration timeout = dnieDefaultTimeout,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) => api
      .readCertificateDetails(
        can,
        pin,
        timeout.inSeconds,
        certificateType.value,
      )
      .then((m) => m.toModel())
      .mapDnieErrors();

  @override
  Future<PersonalData> readPersonalData({
    required String can,
    required String pin,
    Duration timeout = dnieDefaultTimeout,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) => api
      .readPersonalData(can, pin, timeout.inSeconds, certificateType.value)
      .then((m) => m.toModel())
      .mapDnieErrors();

  @override
  Future<void> verifyPin({
    required String can,
    required String pin,
    Duration timeout = dnieDefaultTimeout,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  }) => api
      .verifyPin(can, pin, timeout.inSeconds, certificateType.value)
      .mapDnieErrors();

  @override
  Future<NfcStatus> checkNfcAvailability() =>
      api.checkNfcAvailability().then((m) => m.toModel()).mapDnieErrors();
}
