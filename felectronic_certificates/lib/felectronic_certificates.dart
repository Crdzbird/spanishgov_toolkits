import 'dart:typed_data';

import 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart';

export 'package:felectronic_certificates_platform_interface/felectronic_certificates_platform_interface.dart'
    show
        CertAlreadyExistsError,
        CertImportCancelledError,
        CertIncorrectPasswordError,
        CertKeyUsage,
        CertKeyUsageLabel,
        CertNotFoundError,
        CertNotSelectedError,
        CertSignAlgorithm,
        CertSigningError,
        CertUnknownError,
        CertificateError,
        DeviceCertificate,
        DeviceCertificateParserX,
        DeviceCertificateX,
        X509Certificate,
        X509Extension,
        X509Name,
        X509Parser;

export 'src/certificate_session.dart';

FelectronicCertificatesPlatform get _platform =>
    FelectronicCertificatesPlatform.instance;

/// {@template felectronic_certificates}
/// Flutter plugin for managing device-stored certificates.
///
/// Provides import, sign, list, and delete operations for PKCS#12
/// certificates stored in the Android KeyStore or iOS Keychain.
///
/// ```dart
/// final certs = await getAllCertificates();
/// final signature = await signWithDefaultCertificate(data);
/// ```
/// {@endtemplate}

/// Returns all certificates stored on the device.
Future<List<DeviceCertificate>> getAllCertificates() =>
    _platform.getAllCertificates();

/// Returns the currently selected default certificate, if any.
Future<DeviceCertificate?> getDefaultCertificate() =>
    _platform.getDefaultCertificate();

/// Opens a native certificate picker and returns the selected certificate.
Future<DeviceCertificate?> selectDefaultCertificate() =>
    _platform.selectDefaultCertificate();

/// Sets the default certificate by its [serialNumber].
Future<void> setDefaultCertificateBySerialNumber(String serialNumber) =>
    _platform.setDefaultCertificateBySerialNumber(serialNumber);

/// Clears the default certificate selection.
Future<void> clearDefaultCertificate() =>
    _platform.clearDefaultCertificate();

/// Signs [data] using the default certificate's private key.
///
/// Uses [algorithm] to determine the signing algorithm
/// (defaults to [CertSignAlgorithm.sha256rsa]).
///
/// Throws a [CertificateError] subclass on failure.
Future<Uint8List> signWithDefaultCertificate(
  Uint8List data, {
  CertSignAlgorithm algorithm = CertSignAlgorithm.sha256rsa,
}) =>
    _platform.signWithDefaultCertificate(data, algorithm: algorithm);

/// Imports a PKCS#12 (.p12/.pfx) file into the device keystore.
///
/// [password] is optional if the file is not encrypted.
/// [alias] is an optional label for the imported certificate.
///
/// Throws a [CertificateError] subclass on failure.
Future<void> importCertificate(
  Uint8List pkcs12Data, {
  String? password,
  String? alias,
}) =>
    _platform.importCertificate(pkcs12Data, password: password, alias: alias);

/// Deletes the currently selected default certificate.
///
/// Throws a [CertificateError] subclass on failure.
Future<void> deleteDefaultCertificate() =>
    _platform.deleteDefaultCertificate();

/// Deletes a certificate identified by its [serialNumber].
///
/// Throws a [CertificateError] subclass on failure.
Future<void> deleteCertificateBySerialNumber(String serialNumber) =>
    _platform.deleteCertificateBySerialNumber(serialNumber);
