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

export 'src/dnie_operations.dart';
export 'src/dnie_session.dart';
export 'src/workflows/dnie_identity.dart';
export 'src/workflows/dnie_readiness.dart';
export 'src/workflows/dnie_workflows.dart';
