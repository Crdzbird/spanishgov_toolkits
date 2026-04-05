import 'dart:typed_data';

/// A parsed ASN.1 DER object consisting of tag, value bytes, and header size.
class Asn1Object {
  /// Creates an [Asn1Object] with the given [tag], value [bytes], and
  /// [headerLength].
  const Asn1Object({
    required this.tag,
    required this.bytes,
    required this.headerLength,
  });

  /// The ASN.1 tag byte.
  final int tag;

  /// The value bytes (content after the tag and length encoding).
  final Uint8List bytes;

  /// Number of bytes consumed by the tag and length encoding.
  final int headerLength;

  /// Total number of bytes (header + value).
  int get totalLength => headerLength + bytes.length;

  /// Whether this object uses constructed encoding.
  bool get isConstructed => tag & 0x20 != 0;

  /// Whether this is a context-specific tag.
  bool get isContextTag => tag & 0xC0 == 0x80;

  /// The context tag number (meaningful only when [isContextTag] is true).
  int get contextTagNumber => tag & 0x1F;
}
