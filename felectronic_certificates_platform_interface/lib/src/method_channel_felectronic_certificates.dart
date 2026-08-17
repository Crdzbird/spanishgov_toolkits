import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

/// An implementation of [FelectronicCertificatesPlatform] that uses
/// Pigeon-generated type-safe bindings to communicate with the native
/// platform.
class MethodChannelFelectronicCertificates
    extends FelectronicCertificatesPlatform {
  /// The Pigeon-generated host API used to communicate with native code.
  @visibleForTesting
  FelectronicCertificatesHostApi api = FelectronicCertificatesHostApi();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw CertificateError.fromPlatformException(e);
    }
  }

  @override
  Future<List<DeviceCertificate>> getAllCertificates() => _guard(() async {
    final messages = await api.getAllCertificates();
    return messages
        .whereType<DeviceCertificateMessage>()
        .map(_toCertificate)
        .toList();
  });

  @override
  Future<DeviceCertificate?> getDefaultCertificate() => _guard(() async {
    final message = await api.getDefaultCertificate();
    return message == null ? null : _toCertificate(message);
  });

  @override
  Future<DeviceCertificate?> selectDefaultCertificate() => _guard(() async {
    final message = await api.selectDefaultCertificate();
    return message == null ? null : _toCertificate(message);
  });

  @override
  Future<void> setDefaultCertificateBySerialNumber(
    String serialNumber,
  ) => _guard(
    () => api.setDefaultCertificateBySerialNumber(
      CertificateSerial.canonical(serialNumber),
    ),
  );

  @override
  Future<void> clearDefaultCertificate() => _guard(api.clearDefaultCertificate);

  @override
  Future<Uint8List> signWithDefaultCertificate(
    Uint8List data, {
    CertSignAlgorithm algorithm = CertSignAlgorithm.sha256rsa,
  }) => _guard(() => api.signWithDefaultCertificate(data, algorithm.wire));

  @override
  Future<void> importCertificate(
    Uint8List pkcs12Data, {
    String? password,
    String? alias,
  }) => _guard(() => api.importCertificate(pkcs12Data, password, alias));

  @override
  Future<void> deleteDefaultCertificate() =>
      _guard(api.deleteDefaultCertificate);

  @override
  Future<void> deleteCertificateBySerialNumber(String serialNumber) => _guard(
    () => api.deleteCertificateBySerialNumber(
      CertificateSerial.canonical(serialNumber),
    ),
  );

  DeviceCertificate _toCertificate(DeviceCertificateMessage message) =>
      DeviceCertificate.fromMessage(message);
}
