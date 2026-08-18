import 'dart:convert';
import 'dart:typed_data';

import 'package:felectronic_triphase/src/triphase_protocol.dart';
import 'package:xml/xml.dart';

/// The session document the service returns from pre-sign and expects back at
/// post-sign.
///
/// Its shape is a tree of `<param n="...">` elements. Two matter to the
/// client:
///
/// * `PRE` — the payload the client must sign. Its text is base64.
/// * `PK1` — the signature, which the client adds before post-sign.
///
/// Everything else is the service's own state and is carried through
/// untouched. That is the whole reason the session is handed back rather than
/// re-derived: only the service knows what is in it.
///
/// ## The document is kept as text, not as a tree
///
/// The signature is spliced in by string insertion, and the document is
/// returned exactly as it arrived apart from that insertion. Parsing and
/// re-serializing would be tidier, but a serializer is free to normalize
/// quoting, self-closing tags, whitespace and entity escapes — and the
/// service is handed this document back as its own state. The Android
/// implementation, which is the only one that has run against the real
/// service, does string insertion for exactly this reason.
///
/// Reading is still done with a parser: Android locates `PRE` with the regex
/// `<param n="PRE">(.*?)</param>`, which quietly fails if the value spans a
/// line or the attribute is quoted differently. Parsing to read and splicing
/// to write gives the robustness without the risk.
class TriphaseSession {
  TriphaseSession._(this._xml);

  /// Parses a session document.
  ///
  /// Throws [TriphaseProtocolException] rather than returning an empty
  /// document, so a malformed response cannot be mistaken for a session with
  /// nothing to sign.
  factory TriphaseSession.parse(String xml) {
    if (xml.trim().isEmpty) {
      throw const TriphaseProtocolException('the session document was empty');
    }
    try {
      XmlDocument.parse(xml);
    } on XmlException catch (error) {
      throw TriphaseProtocolException(
        'the session document is not valid XML: '
        '${error.message}',
      );
    }
    return TriphaseSession._(xml);
  }

  String _xml;

  static const _preTag = '<param n="PRE">';
  static const _closeTag = '</param>';

  XmlElement? _param(String name) {
    for (final element in XmlDocument.parse(_xml).findAllElements('param')) {
      if (element.getAttribute('n') == name) return element;
    }
    return null;
  }

  /// The payload to sign, decoded from the `PRE` parameter.
  ///
  /// Decoded rather than handed back as base64 text: what gets signed is the
  /// bytes, and returning the text invites a caller to sign the encoding
  /// instead. Android decodes here too.
  Uint8List get payloadToSign {
    final element = _param('PRE');
    if (element == null) {
      throw const TriphaseProtocolException(
        'the session document has no PRE parameter, '
        'so there is nothing to sign',
      );
    }
    final text = element.innerText.trim();
    if (text.isEmpty) {
      throw const TriphaseProtocolException('the PRE parameter was empty');
    }
    return TriphaseCodec.decode(text);
  }

  /// Whether the service has already been given a signature.
  bool get hasSignature => _param('PK1') != null;

  /// Splices the PKCS#1 signature in as a `PK1` parameter.
  ///
  /// Placed immediately after `PRE` closes, which is where Android puts it.
  /// Appending to the end of the enclosing element would also be valid XML,
  /// but position is not something to differ from the working implementation
  /// on when the service's parsing is unknown.
  void attachSignature(Uint8List signature) {
    if (hasSignature) {
      throw const TriphaseProtocolException(
        'this session already carries a signature',
      );
    }
    final start = _xml.indexOf(_preTag);
    if (start == -1) {
      throw const TriphaseProtocolException(
        'cannot attach a signature to a session with no PRE parameter',
      );
    }
    final close = _xml.indexOf(_closeTag, start + _preTag.length);
    if (close == -1) {
      throw const TriphaseProtocolException(
        'the PRE parameter is not closed',
      );
    }
    final insertAt = close + _closeTag.length;
    final pk1 = '<param n="PK1">${base64.encode(signature)}</param>';
    _xml = '${_xml.substring(0, insertAt)}\n$pk1\n${_xml.substring(insertAt)}';
  }

  /// The document as text, for the post-sign request.
  String toXmlString() => _xml;
}
