import 'dart:typed_data';

import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// An in-memory keychain standing in for the native side.
final class FakeCertificatesPlatform extends FelectronicCertificatesPlatform
    with MockPlatformInterfaceMixin {
  /// A fresh fake, registered as the platform instance.
  factory FakeCertificatesPlatform.installed() {
    final platform = FakeCertificatesPlatform._();
    FelectronicCertificatesPlatform.instance = platform;
    return platform;
  }

  FakeCertificatesPlatform._();

  final List<DeviceCertificate> certificates = [];
  final List<String> deleted = [];
  String? defaultSerial;
  DeviceCertificate? pickedByNativePicker;

  @override
  Future<List<DeviceCertificate>> getAllCertificates() async => certificates;

  @override
  Future<DeviceCertificate?> getDefaultCertificate() async =>
      certificates.where((c) => c.serialNumber == defaultSerial).firstOrNull;

  @override
  Future<DeviceCertificate?> selectDefaultCertificate() async =>
      pickedByNativePicker;

  @override
  Future<void> setDefaultCertificateBySerialNumber(String serialNumber) async =>
      defaultSerial = serialNumber;

  @override
  Future<void> clearDefaultCertificate() async => defaultSerial = null;

  @override
  Future<Uint8List> signWithDefaultCertificate(
    Uint8List data, {
    CertSignAlgorithm algorithm = CertSignAlgorithm.sha256rsa,
  }) async => Uint8List.fromList([1]);

  @override
  Future<void> importCertificate(
    Uint8List pkcs12Data, {
    String? password,
    String? alias,
  }) async {}

  @override
  Future<void> deleteDefaultCertificate() async {}

  @override
  Future<void> deleteCertificateBySerialNumber(String serialNumber) async =>
      deleted.add(serialNumber);
}

/// A certificate as the keychain reports it.
DeviceCertificate certificate(
  String serial, {
  String? alias,
  DateTime? expires,
}) => DeviceCertificate(
  serialNumber: serial,
  alias: alias,
  holderName: 'Holder $serial',
  issuerName: 'Test CA',
  expirationDate: expires ?? DateTime.utc(2099),
  usages: const [],
  encoded: Uint8List.fromList([0x30, serial.length]),
);
