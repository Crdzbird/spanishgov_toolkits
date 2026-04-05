import 'dart:convert';
import 'dart:typed_data';

import 'package:felectronic_x509/src/asn1/asn1_object.dart';
import 'package:felectronic_x509/src/asn1/asn1_reader.dart';
import 'package:felectronic_x509/src/asn1/asn1_tag.dart';
import 'package:felectronic_x509/src/x509/x509_certificate.dart';
import 'package:felectronic_x509/src/x509/x509_extension.dart';
import 'package:felectronic_x509/src/x509/x509_name.dart';
import 'package:felectronic_x509/src/x509/x509_public_key.dart';

/// Parses DER-encoded X.509 certificates into [X509Certificate] objects.
///
/// All methods throw [FormatException] on invalid or malformed input.
abstract final class X509Parser {
  /// Parse DER-encoded bytes into an [X509Certificate].
  static X509Certificate fromDer(Uint8List derBytes) {
    try {
      return _parseDer(derBytes);
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      throw FormatException('Failed to parse X.509 certificate: $e');
    }
  }

  /// Parse a PEM-encoded certificate string.
  static X509Certificate fromPem(String pem) {
    final b64 = pem
        .replaceAll('-----BEGIN CERTIFICATE-----', '')
        .replaceAll('-----END CERTIFICATE-----', '')
        .replaceAll(RegExp(r'\s'), '');
    if (b64.isEmpty) {
      throw const FormatException('PEM string contains no certificate data');
    }
    return fromBase64(b64);
  }

  /// Parse a base64-encoded DER string.
  static X509Certificate fromBase64(String base64Der) {
    final Uint8List bytes;
    try {
      bytes = base64.decode(base64Der);
    } on Object catch (e) {
      throw FormatException('Invalid base64 encoding: $e');
    }
    return fromDer(bytes);
  }

  // ---------------------------------------------------------------------------
  // Internal parsing
  // ---------------------------------------------------------------------------

  static X509Certificate _parseDer(Uint8List derBytes) {
    final outerReader = Asn1Reader(derBytes);
    final certSeq = outerReader.readSequence();

    // --- TBS Certificate ---
    // We need the raw bytes of the TBS SEQUENCE for signature verification.
    final tbsStart = certSeq.offset;
    final tbsReader = certSeq.readSequence();
    final tbsEnd = certSeq.offset;
    final tbsCertificateBytes =
        Uint8List.sublistView(derBytes, tbsStart, tbsEnd);

    // Version: explicit [0] containing an INTEGER
    var version = 1; // default is v1
    final versionCtx = tbsReader.readContextTag(0);
    if (versionCtx != null) {
      version = (versionCtx.readInteger().toInt()) + 1;
    }

    // Serial number
    final serialBigInt = tbsReader.readInteger();
    final serialNumber = serialBigInt
        .toUnsigned(serialBigInt.bitLength + 8)
        .toRadixString(16)
        .toUpperCase();

    // Signature algorithm (inside TBS)
    final sigAlgReader = tbsReader.readSequence();
    final signatureAlgorithm = sigAlgReader.readOid();

    // Issuer
    final issuer = _parseName(tbsReader.readSequence());

    // Validity
    final validityReader = tbsReader.readSequence();
    final notValidBefore = validityReader.readTime();
    final notValidAfter = validityReader.readTime();

    // Subject
    final subject = _parseName(tbsReader.readSequence());

    // SubjectPublicKeyInfo
    final spkiReader = tbsReader.readSequence();
    final pkAlgReader = spkiReader.readSequence();
    final pkAlgOid = pkAlgReader.readOid();
    String? pkParamOid;
    if (pkAlgReader.hasMore) {
      final paramObj = pkAlgReader.readObject();
      if (paramObj.tag == Asn1Tag.oid) {
        pkParamOid = Asn1Reader.decodeOid(paramObj.bytes);
      }
    }
    final publicKeyBytes = spkiReader.readBitString();
    final publicKeyAlgorithm = X509PublicKeyUtil.algorithmName(pkAlgOid);
    final publicKeySize = X509PublicKeyUtil.keySize(
      algorithmOid: pkAlgOid,
      keyBytes: publicKeyBytes,
      parameterOid: pkParamOid,
    );

    // Extensions (optional, in [3])
    // First skip issuerUniqueID [1] and subjectUniqueID [2] if present.
    tbsReader
      ..skipContextTag(1)
      ..skipContextTag(2);
    final extensions = <X509Extension>[];
    final extCtx = tbsReader.readContextTag(3);
    if (extCtx != null) {
      final extSeq = extCtx.readSequence();
      while (extSeq.hasMore) {
        final ext = _parseExtension(extSeq.readSequence());
        extensions.add(ext);
      }
    }

    // --- Signature Algorithm (outer, after TBS) ---
    // We already parsed the one inside TBS; just skip the outer copy.
    certSeq.readSequence(); // signatureAlgorithm (outer)

    // --- Signature Value ---
    final signatureBytes = certSeq.readBitString();

    return X509Certificate(
      version: version,
      serialNumber: serialNumber,
      signatureAlgorithm: signatureAlgorithm,
      issuer: issuer,
      subject: subject,
      notValidBefore: notValidBefore,
      notValidAfter: notValidAfter,
      publicKeyAlgorithm: publicKeyAlgorithm,
      publicKeySize: publicKeySize,
      publicKeyBytes: publicKeyBytes,
      extensions: extensions,
      signatureBytes: signatureBytes,
      tbsCertificateBytes: tbsCertificateBytes,
      derEncoded: derBytes,
    );
  }

  static X509Name _parseName(Asn1Reader nameReader) {
    final attrs = <String, String>{};
    while (nameReader.hasMore) {
      final rdn = nameReader.readSet();
      while (rdn.hasMore) {
        final atv = rdn.readSequence();
        final oid = atv.readOid();
        final valueObj = atv.readObject();
        final value = _decodeNameValue(valueObj);
        attrs[oid] = value;
      }
    }
    return X509Name(attrs);
  }

  static String _decodeNameValue(Asn1Object obj) {
    if (obj.tag == Asn1Tag.bmpString) {
      final buf = StringBuffer();
      for (var i = 0; i + 1 < obj.bytes.length; i += 2) {
        buf.writeCharCode((obj.bytes[i] << 8) | obj.bytes[i + 1]);
      }
      return buf.toString();
    }
    return utf8.decode(obj.bytes, allowMalformed: true);
  }

  static X509Extension _parseExtension(Asn1Reader extReader) {
    final oid = extReader.readOid();
    var isCritical = false;
    // The next element is either a BOOLEAN (critical) or an OCTET STRING.
    if (extReader.hasMore && extReader.peekTag() == Asn1Tag.boolean) {
      final boolObj = extReader.readObject();
      isCritical = boolObj.bytes.isNotEmpty && boolObj.bytes[0] != 0;
    }
    final value = extReader.readOctetString();
    return X509Extension(oid: oid, isCritical: isCritical, value: value);
  }
}
