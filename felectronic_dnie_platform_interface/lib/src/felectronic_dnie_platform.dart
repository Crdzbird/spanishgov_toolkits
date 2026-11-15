import 'dart:typed_data';

import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// {@template felectronic_dnie_platform}
/// The interface that implementations of felectronic_dnie must implement.
///
/// Implementations should extend this class rather than implement it, so
/// newly added methods do not break them.
/// {@endtemplate}
abstract class FelectronicDniePlatform extends PlatformInterface {
  /// {@macro felectronic_dnie_platform}
  FelectronicDniePlatform() : super(token: _token);

  static final Object _token = Object();

  static FelectronicDniePlatform _instance = MethodChannelFelectronicDnie();

  /// The instance in use, [MethodChannelFelectronicDnie] by default.
  static FelectronicDniePlatform get instance => _instance;

  /// Set by each platform implementation when it registers itself.
  static set instance(FelectronicDniePlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Signs [data] on the device with the private key of [certificateType].
  ///
  /// [SignedData.signedData] is the raw PKCS#1 v1.5 signature, SHA-512 with
  /// RSA, and [SignedData.certificate] the certificate as standard Base64
  /// DER. Nothing leaves the device. [can] is the 6 digit Card Access Number,
  /// [pin] the 8 to 16 character PIN, and [timeout] how long to wait for a
  /// card (see [dnieDefaultTimeout]). Throws [DnieError].
  Future<SignedData> sign({
    required Uint8List data,
    required String can,
    required String pin,
    Duration timeout = dnieDefaultTimeout,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  });

  /// Signs [data] as CAdES through the three-phase protocol, sending [data]
  /// and the certificate chain to the remote signing service.
  ///
  /// [SignedData.signedData] is the CAdES signature. Takes the same arguments
  /// as [sign]. Throws [DnieUnsupportedError] where the platform lacks it.
  Future<SignedData> signCades({
    required Uint8List data,
    required String can,
    required String pin,
    Duration timeout = dnieDefaultTimeout,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  });

  /// Stops the NFC operation in progress, failing it with [DnieCancelledError].
  Future<void> stopSign();

  /// Reads the [certificateType] certificate without signing anything.
  ///
  /// Only [SignedData.certificate] is populated.
  Future<SignedData> readCertificate({
    required String can,
    required String pin,
    Duration timeout = dnieDefaultTimeout,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  });

  /// Probes an NFC card to check if it is a valid Spanish DNIe, with no CAN
  /// or PIN.
  Future<CardProbeResult> probeCard({Duration timeout = dnieDefaultTimeout});

  /// Reads and parses the [certificateType] certificate's X.509 details.
  Future<CertificateInfo> readCertificateDetails({
    required String can,
    required String pin,
    Duration timeout = dnieDefaultTimeout,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  });

  /// Reads the holder's name and NIF from the certificate subject.
  Future<PersonalData> readPersonalData({
    required String can,
    required String pin,
    Duration timeout = dnieDefaultTimeout,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  });

  /// Verifies [can] and [pin] without signing. Throws [DnieError] if wrong.
  Future<void> verifyPin({
    required String can,
    required String pin,
    Duration timeout = dnieDefaultTimeout,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  });

  /// Checks if NFC hardware is available and enabled on the device.
  Future<NfcStatus> checkNfcAvailability();
}
