import 'dart:typed_data';

import 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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

  /// Signs [data] with the private key of [certificateType] via NFC.
  ///
  /// [can] is the 6 digit Card Access Number, [pin] the 8 to 16 character
  /// PIN, and [timeout] the seconds to wait for a card. Throws [DnieError].
  Future<SignedData> sign({
    required Uint8List data,
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  });

  /// Stops an in-progress NFC signing operation.
  Future<void> stopSign();

  /// Reads the [certificateType] certificate without signing anything.
  ///
  /// Only [SignedData.certificate] is populated.
  Future<SignedData> readCertificate({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  });

  /// Probes an NFC card to check if it is a valid Spanish DNIe.
  ///
  /// No CAN or PIN required.
  Future<CardProbeResult> probeCard({int timeout = 30});

  /// Reads and parses the [certificateType] certificate's X.509 details.
  Future<CertificateInfo> readCertificateDetails({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  });

  /// Reads the holder's name and NIF from the certificate subject.
  Future<PersonalData> readPersonalData({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  });

  /// Verifies [can] and [pin] without signing. Throws [DnieError] if wrong.
  Future<void> verifyPin({
    required String can,
    required String pin,
    int timeout = 30,
    DnieCertificateType certificateType = DnieCertificateType.sign,
  });

  /// Checks if NFC hardware is available and enabled on the device.
  Future<NfcStatus> checkNfcAvailability();
}
