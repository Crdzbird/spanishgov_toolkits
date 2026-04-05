import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The Android implementation of [FelectronicCertificatesPlatform].
class FelectronicCertificatesAndroid extends FelectronicCertificatesPlatform {
  /// The Pigeon-generated host API used to communicate with native code.
  @visibleForTesting
  FelectronicCertificatesHostApi api = FelectronicCertificatesHostApi();

  /// Registers this class as the default instance of
  /// [FelectronicCertificatesPlatform].
  static void registerWith() {
    FelectronicCertificatesPlatform.instance =
        FelectronicCertificatesAndroid();
  }

  @override
  Future<List<DeviceCertificate>> getAllCertificates() async {
    try {
      final messages = await api.getAllCertificates();
      return messages
          .whereType<DeviceCertificateMessage>()
          .map(_toCertificate)
          .toList();
    } on PlatformException catch (e) {
      throw CertificateError.fromPlatformException(e);
    }
  }

  @override
  Future<DeviceCertificate?> getDefaultCertificate() async {
    try {
      final message = await api.getDefaultCertificate();
      return message == null ? null : _toCertificate(message);
    } on PlatformException catch (e) {
      throw CertificateError.fromPlatformException(e);
    }
  }

  @override
  Future<DeviceCertificate?> selectDefaultCertificate() async {
    try {
      final message = await api.selectDefaultCertificate();
      return message == null ? null : _toCertificate(message);
    } on PlatformException catch (e) {
      throw CertificateError.fromPlatformException(e);
    }
  }

  @override
  Future<void> setDefaultCertificateBySerialNumber(
    String serialNumber,
  ) async {
    try {
      await api.setDefaultCertificateBySerialNumber(serialNumber);
    } on PlatformException catch (e) {
      throw CertificateError.fromPlatformException(e);
    }
  }

  @override
  Future<void> clearDefaultCertificate() async {
    try {
      await api.clearDefaultCertificate();
    } on PlatformException catch (e) {
      throw CertificateError.fromPlatformException(e);
    }
  }

  @override
  Future<Uint8List> signWithDefaultCertificate(
    Uint8List data, {
    CertSignAlgorithm algorithm = CertSignAlgorithm.sha256rsa,
  }) async {
    try {
      return await api.signWithDefaultCertificate(data, algorithm.value);
    } on PlatformException catch (e) {
      throw CertificateError.fromPlatformException(e);
    }
  }

  @override
  Future<void> importCertificate(
    Uint8List pkcs12Data, {
    String? password,
    String? alias,
  }) async {
    try {
      await api.importCertificate(pkcs12Data, password, alias);
    } on PlatformException catch (e) {
      throw CertificateError.fromPlatformException(e);
    }
  }

  @override
  Future<void> deleteDefaultCertificate() async {
    try {
      await api.deleteDefaultCertificate();
    } on PlatformException catch (e) {
      throw CertificateError.fromPlatformException(e);
    }
  }

  @override
  Future<void> deleteCertificateBySerialNumber(String serialNumber) async {
    try {
      await api.deleteCertificateBySerialNumber(serialNumber);
    } on PlatformException catch (e) {
      throw CertificateError.fromPlatformException(e);
    }
  }

  DeviceCertificate _toCertificate(DeviceCertificateMessage message) {
    final parts = message.expirationDate.split('-');
    final expiration = DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );

    return DeviceCertificate(
      serialNumber: message.serialNumber,
      alias: message.alias,
      holderName: message.holderName,
      issuerName: message.issuerName,
      expirationDate: expiration,
      usages: CertKeyUsage.parseUsages(message.usages),
      encoded: message.encoded,
    );
  }
}
