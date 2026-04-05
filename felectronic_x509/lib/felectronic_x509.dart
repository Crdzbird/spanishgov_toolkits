/// Pure Dart X.509 certificate parser for DER-encoded bytes.
///
/// This package provides a zero-dependency (aside from `dart:typed_data` and
/// `dart:convert`) parser for X.509 certificates. It includes a low-level
/// ASN.1 DER reader and a high-level certificate model.
///
/// ```dart
/// import 'package:felectronic_x509/felectronic_x509.dart';
///
/// final cert = X509Parser.fromDer(derBytes);
/// print(cert.subject.commonName);
/// ```
library felectronic_x509;

export 'src/asn1/asn1_object.dart';
export 'src/asn1/asn1_reader.dart';
export 'src/asn1/asn1_tag.dart';
export 'src/x509/x509_certificate.dart';
export 'src/x509/x509_extension.dart';
export 'src/x509/x509_name.dart';
export 'src/x509/x509_parser.dart';
export 'src/x509/x509_public_key.dart';
