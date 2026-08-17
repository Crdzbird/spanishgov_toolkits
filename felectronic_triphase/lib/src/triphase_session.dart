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
class TriphaseSession {
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
      return TriphaseSession._(XmlDocument.parse(xml));
    } on XmlException catch (error) {
      throw TriphaseProtocolException(
        'the session document is not valid XML: '
        '${error.message}',
      );
    }
  }
  TriphaseSession._(this._document);

  final XmlDocument _document;

  /// Every `<param>` in the document, at any depth.
  Iterable<XmlElement> get _params => _document.findAllElements('param');

  XmlElement? _param(String name) {
    for (final element in _params) {
      if (element.getAttribute('n') == name) return element;
    }
    return null;
  }

  /// The payload to sign, decoded from the `PRE` parameter.
  ///
  /// The original client returned the base64 *text* rather than its decoded
  /// bytes, leaving the caller to decide what to do with it. This decodes,
  /// because what gets signed is the bytes; handing back a string invites the
  /// caller to sign the base64 of the payload instead of the payload.
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

  /// Adds the PKCS#1 signature as a `PK1` parameter, beside `PRE`.
  ///
  /// Placing it beside `PRE` matters: the service reads the pair together. The
  /// original client appended to every second-level element it found, which
  /// would add a `PK1` to unrelated branches of a document with more than one.
  void attachSignature(Uint8List signature) {
    if (hasSignature) {
      throw const TriphaseProtocolException(
        'this session already carries a signature',
      );
    }
    final pre = _param('PRE');
    if (pre == null) {
      throw const TriphaseProtocolException(
        'cannot attach a signature to a session with no PRE parameter',
      );
    }
    final parent = pre.parent;
    if (parent == null) {
      throw const TriphaseProtocolException('the PRE parameter has no parent');
    }

    parent.children.add(
      XmlElement(
        XmlName('param'),
        [XmlAttribute(XmlName('n'), 'PK1')],
        [XmlText(base64.encode(signature))],
      ),
    );
  }

  /// The document as text, for the post-sign request.
  String toXmlString() => _document.toXmlString();
}
