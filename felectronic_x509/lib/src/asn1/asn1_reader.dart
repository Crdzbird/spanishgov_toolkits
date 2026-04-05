import 'dart:convert';
import 'dart:typed_data';

import 'package:felectronic_x509/src/asn1/asn1_object.dart';
import 'package:felectronic_x509/src/asn1/asn1_tag.dart';

/// Low-level ASN.1 DER reader that walks a byte buffer extracting TLV
/// (Tag-Length-Value) structures.
class Asn1Reader {
  /// Creates a reader over the given byte buffer starting at the given
  /// position.
  Asn1Reader(this._bytes, [this._offset = 0])
      : _end = _bytes.length;

  /// Creates a reader over a sub-range of the byte buffer.
  Asn1Reader._(this._bytes, this._offset, this._end);

  final Uint8List _bytes;
  int _offset;
  final int _end;

  /// Whether there are more bytes to read within the current scope.
  bool get hasMore => _offset < _end;

  /// Current read position.
  int get offset => _offset;

  // ---------------------------------------------------------------------------
  // Core TLV reading
  // ---------------------------------------------------------------------------

  /// Read the next ASN.1 object (tag + length + value).
  Asn1Object readObject() {
    _ensureAvailable(2, 'reading ASN.1 object');
    final startOffset = _offset;
    final tag = _bytes[_offset++];
    final length = _readLength();
    final headerLength = _offset - startOffset;
    _ensureAvailable(
      length,
      'reading ASN.1 value for tag 0x${tag.toRadixString(16)}',
    );
    final value = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return Asn1Object(tag: tag, bytes: value, headerLength: headerLength);
  }

  /// Peek at the next tag without advancing the offset.
  int peekTag() {
    _ensureAvailable(1, 'peeking at ASN.1 tag');
    return _bytes[_offset];
  }

  // ---------------------------------------------------------------------------
  // Structured reads
  // ---------------------------------------------------------------------------

  /// Read a SEQUENCE and return a reader scoped to its contents.
  Asn1Reader readSequence() {
    final obj = readObject();
    if (obj.tag != Asn1Tag.sequence) {
      throw FormatException(
        'Expected SEQUENCE (0x30), got 0x${obj.tag.toRadixString(16)}',
      );
    }
    return _readerFor(obj);
  }

  /// Read a SET and return a reader scoped to its contents.
  Asn1Reader readSet() {
    final obj = readObject();
    if (obj.tag != Asn1Tag.set_) {
      throw FormatException(
        'Expected SET (0x31), got 0x${obj.tag.toRadixString(16)}',
      );
    }
    return _readerFor(obj);
  }

  /// Read an INTEGER as [BigInt].
  BigInt readInteger() {
    final obj = readObject();
    if (obj.tag != Asn1Tag.integer) {
      throw FormatException(
        'Expected INTEGER (0x02), got 0x${obj.tag.toRadixString(16)}',
      );
    }
    return _decodeBigInt(obj.bytes);
  }

  /// Read an OBJECT IDENTIFIER as a dot-separated string
  /// (e.g. `"2.5.4.3"`).
  String readOid() {
    final obj = readObject();
    if (obj.tag != Asn1Tag.oid) {
      throw FormatException(
        'Expected OID (0x06), got 0x${obj.tag.toRadixString(16)}',
      );
    }
    return decodeOid(obj.bytes);
  }

  /// Read a BIT STRING and return the content bytes (without the
  /// unused-bits prefix byte).
  Uint8List readBitString() {
    final obj = readObject();
    if (obj.tag != Asn1Tag.bitString) {
      throw FormatException(
        'Expected BIT STRING (0x03), got 0x${obj.tag.toRadixString(16)}',
      );
    }
    if (obj.bytes.isEmpty) {
      throw const FormatException('BIT STRING is empty');
    }
    // First byte is the number of unused bits in the last byte.
    return Uint8List.sublistView(obj.bytes, 1);
  }

  /// Read a BIT STRING including the unused-bits byte.
  Uint8List readBitStringRaw() {
    final obj = readObject();
    if (obj.tag != Asn1Tag.bitString) {
      throw FormatException(
        'Expected BIT STRING (0x03), got 0x${obj.tag.toRadixString(16)}',
      );
    }
    return obj.bytes;
  }

  /// Read an OCTET STRING.
  Uint8List readOctetString() {
    final obj = readObject();
    if (obj.tag != Asn1Tag.octetString) {
      throw FormatException(
        'Expected OCTET STRING (0x04), got 0x${obj.tag.toRadixString(16)}',
      );
    }
    return obj.bytes;
  }

  /// Read a string value (UTF8String, PrintableString, IA5String,
  /// T61String, or BMPString).
  String readString() {
    final obj = readObject();
    return _decodeString(obj);
  }

  /// Read a UTCTime or GeneralizedTime as [DateTime].
  DateTime readTime() {
    final obj = readObject();
    final s = utf8.decode(obj.bytes);
    if (obj.tag == Asn1Tag.utcTime) {
      return _parseUtcTime(s);
    } else if (obj.tag == Asn1Tag.generalizedTime) {
      return _parseGeneralizedTime(s);
    }
    throw FormatException(
      'Expected UTCTime or GeneralizedTime, got 0x${obj.tag.toRadixString(16)}',
    );
  }

  /// Skip a context-tagged `[n]` element if it is the next element.
  /// Returns `true` if it was present and skipped.
  bool skipContextTag(int n) {
    if (!hasMore) return false;
    final expectedTag = 0xA0 | n;
    if (_bytes[_offset] == expectedTag) {
      readObject(); // consume and discard
      return true;
    }
    return false;
  }

  /// Read a context-tagged `[n]` and return a reader over its contents,
  /// or `null` if the next element is not that tag.
  Asn1Reader? readContextTag(int n) {
    if (!hasMore) return null;
    final expectedTag = 0xA0 | n;
    if (_bytes[_offset] == expectedTag) {
      final obj = readObject();
      return _readerFor(obj);
    }
    return null;
  }

  /// Skip the current ASN.1 object.
  void skip() {
    readObject();
  }

  /// Read all remaining bytes in the current scope.
  Uint8List readRemaining() {
    final result = Uint8List.sublistView(_bytes, _offset, _end);
    _offset = _end;
    return result;
  }

  // ---------------------------------------------------------------------------
  // Static helpers
  // ---------------------------------------------------------------------------

  /// Decode an OID from its DER-encoded value bytes.
  static String decodeOid(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('OID value is empty');
    }
    // First byte encodes first two components.
    final components = <int>[
      bytes[0] ~/ 40,
      bytes[0] % 40,
    ];

    var value = 0;
    for (var i = 1; i < bytes.length; i++) {
      final b = bytes[i];
      value = (value << 7) | (b & 0x7F);
      if (b & 0x80 == 0) {
        components.add(value);
        value = 0;
      }
    }
    return components.join('.');
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  int _readLength() {
    _ensureAvailable(1, 'reading ASN.1 length');
    final first = _bytes[_offset++];
    if (first < 0x80) return first;
    if (first == 0x80) {
      throw const FormatException(
        'Indefinite-length encoding is not supported in DER',
      );
    }
    final numBytes = first & 0x7F;
    if (numBytes > 4) {
      throw FormatException('ASN.1 length too large: $numBytes bytes');
    }
    _ensureAvailable(numBytes, 'reading ASN.1 multi-byte length');
    var length = 0;
    for (var i = 0; i < numBytes; i++) {
      length = (length << 8) | _bytes[_offset++];
    }
    return length;
  }

  void _ensureAvailable(int needed, String context) {
    if (_offset + needed > _end) {
      throw FormatException(
        'Unexpected end of data while $context '
        '(need $needed bytes at offset $_offset, '
        'but only ${_end - _offset} remain)',
      );
    }
  }

  Asn1Reader _readerFor(Asn1Object obj) {
    // The obj.bytes is a view into _bytes; compute the absolute positions.
    final start = _offset - obj.bytes.length;
    return Asn1Reader._(_bytes, start, start + obj.bytes.length);
  }

  static BigInt _decodeBigInt(Uint8List bytes) {
    if (bytes.isEmpty) return BigInt.zero;
    final negative = bytes[0] & 0x80 != 0;
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    if (negative) {
      // Two's complement for the byte length.
      result -= BigInt.one << (bytes.length * 8);
    }
    return result;
  }

  static String _decodeString(Asn1Object obj) {
    switch (obj.tag) {
      case Asn1Tag.utf8String:
      case Asn1Tag.printableString:
      case Asn1Tag.ia5String:
      case Asn1Tag.t61String:
        return utf8.decode(obj.bytes, allowMalformed: true);
      case Asn1Tag.bmpString:
        return _decodeBmpString(obj.bytes);
      default:
        // Best-effort for unknown string types.
        return utf8.decode(obj.bytes, allowMalformed: true);
    }
  }

  static String _decodeBmpString(Uint8List bytes) {
    final buf = StringBuffer();
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      buf.writeCharCode((bytes[i] << 8) | bytes[i + 1]);
    }
    return buf.toString();
  }

  static DateTime _parseUtcTime(String s) {
    // YYMMDDhhmmssZ or YYMMDDhhmmZ
    if (s.length < 11) {
      throw FormatException('Invalid UTCTime: $s');
    }
    var year = int.parse(s.substring(0, 2));
    year += year >= 50 ? 1900 : 2000;
    final month = int.parse(s.substring(2, 4));
    final day = int.parse(s.substring(4, 6));
    final hour = int.parse(s.substring(6, 8));
    final minute = int.parse(s.substring(8, 10));
    final second = s.length >= 12 && s[10] != 'Z'
        ? int.parse(s.substring(10, 12))
        : 0;
    return DateTime.utc(year, month, day, hour, minute, second);
  }

  static DateTime _parseGeneralizedTime(String s) {
    // YYYYMMDDhhmmssZ
    if (s.length < 14) {
      throw FormatException('Invalid GeneralizedTime: $s');
    }
    final year = int.parse(s.substring(0, 4));
    final month = int.parse(s.substring(4, 6));
    final day = int.parse(s.substring(6, 8));
    final hour = int.parse(s.substring(8, 10));
    final minute = int.parse(s.substring(10, 12));
    final second = int.parse(s.substring(12, 14));
    return DateTime.utc(year, month, day, hour, minute, second);
  }
}
