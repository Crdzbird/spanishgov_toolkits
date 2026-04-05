import 'dart:typed_data';

import 'package:felectronic_dnie_platform_interface/src/errors/dnie_error.dart';
import 'package:felectronic_dnie_platform_interface/src/method_channel_felectronic_dnie.dart';
import 'package:felectronic_dnie_platform_interface/src/models/card_probe_result.dart';
import 'package:felectronic_dnie_platform_interface/src/models/certificate_info.dart';
import 'package:felectronic_dnie_platform_interface/src/models/dnie_certificate_type.dart';
import 'package:felectronic_dnie_platform_interface/src/models/nfc_status.dart';
import 'package:felectronic_dnie_platform_interface/src/models/personal_data.dart';
import 'package:felectronic_dnie_platform_interface/src/models/signed_data.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

export 'package:felectronic_x509/felectronic_x509.dart';

export 'src/errors/dnie_error.dart';
export 'src/generated/messages.g.dart';
export 'src/models/card_probe_result.dart';
export 'src/models/certificate_info.dart';
export 'src/models/dnie_certificate_type.dart';
export 'src/models/nfc_status.dart';
export 'src/models/personal_data.dart';
export 'src/models/signed_data.dart';
export 'src/utils/dnie_validators.dart';
export 'src/utils/model_extensions.dart';

/// {@template felectronic_dnie_platform}
/// The interface that implementations of felectronic_dnie must implement.
///
/// Platform implementations should extend this class
/// rather than implement it as `FelectronicDnie`.
///
/// Extending this class (using `extends`) ensures that the subclass will get
/// the default implementation, while platform implementations that
/// `implements` this interface will be broken by newly added
/// [FelectronicDniePlatform] methods.
/// {@endtemplate}
abstract class FelectronicDniePlatform extends PlatformInterface {
  /// {@macro felectronic_dnie_platform}
  FelectronicDniePlatform() : super(token: _token);

  static final Object _token = Object();

  static FelectronicDniePlatform _instance = MethodChannelFelectronicDnie();

  /// The default instance of [FelectronicDniePlatform] to use.
  ///
  /// Defaults to [MethodChannelFelectronicDnie].
  static FelectronicDniePlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own
  /// platform-specific class that extends [FelectronicDniePlatform]
  /// when they register themselves.
  static set instance(FelectronicDniePlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Signs [data] using the DNIe private key via NFC.
  ///
  /// Requires the card's [can] (Card Access Number, 6 digits) and [pin]
  /// (8-16 alphanumeric characters). The [timeout] is in seconds.
  /// The [certificateType] selects which certificate to use
  /// (`SIGN` for signatures, `AUTH` for authentication).
  ///
  /// Throws [DnieError] on failure.
  Future<SignedData> sign({
    required Uint8List data,
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  });

  /// Stops an in-progress NFC signing operation.
  Future<void> stopSign();

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
  });

  /// Probes an NFC card to check if it is a valid Spanish DNIe.
  ///
  /// No CAN or PIN required. Returns card metadata including
  /// ATR historical bytes and tag identifier.
  Future<CardProbeResult> probeCard({int timeout = 30});

  /// Reads and parses X.509 certificate details from the DNIe.
  ///
  /// Returns structured certificate metadata including subject,
  /// issuer, validity period, and serial number.
  ///
  /// Use [certificateType] to select SIGN (default) or AUTH certificate.
  Future<CertificateInfo> readCertificateDetails({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  });

  /// Reads personal data from the DNIe certificate subject DN.
  ///
  /// Returns identity information extracted from the certificate,
  /// including name, NIF, and certificate type.
  ///
  /// Use [certificateType] to select SIGN (default) or AUTH certificate.
  Future<PersonalData> readPersonalData({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  });

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
  });

  /// Checks if NFC hardware is available and enabled on the device.
  ///
  /// Returns an [NfcStatus] with [NfcStatus.isAvailable] and
  /// [NfcStatus.isEnabled].
  Future<NfcStatus> checkNfcAvailability();
}
