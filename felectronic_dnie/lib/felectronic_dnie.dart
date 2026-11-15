/// Flutter plugin for reading and signing with the Spanish electronic DNIe
/// (Documento Nacional de Identidad electronico) via NFC.
///
/// ```dart
/// final result = await sign(
///   data: utf8.encode('Hello, DNIe!'),
///   can: '123456',
///   pin: 'mySecurePin',
/// );
/// print(result.signedDataBase64);
/// ```
///
/// `sign` signs on the device and returns the raw PKCS#1 v1.5 signature.
/// `signCades` (Android only) returns CAdES from the remote service.
library;

export 'package:felectronic_dnie_platform_interface/felectronic_dnie_platform_interface.dart'
    hide
        Asn1Object,
        Asn1Reader,
        Asn1Tag,
        DnieCardProbeMessage,
        DnieCertificateDetailsMessage,
        DnieNfcStatusMessage,
        DniePersonalDataMessage,
        DnieSignedDataMessage,
        FelectronicDnieHostApi,
        FelectronicDniePlatform,
        MethodChannelFelectronicDnie,
        X509PublicKeyUtil;

export 'src/dnie_cades_operations.dart';
export 'src/dnie_operations.dart';
export 'src/dnie_session.dart';
export 'src/workflows/dnie_identity.dart';
export 'src/workflows/dnie_readiness.dart';
export 'src/workflows/dnie_workflows.dart';
