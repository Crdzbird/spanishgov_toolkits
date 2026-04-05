import 'dart:typed_data';

import 'package:felectronic_x509/felectronic_x509.dart';
import 'package:test/test.dart';

Uint8List _hex(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s'), '');
  final bytes = <int>[];
  for (var i = 0; i < clean.length; i += 2) {
    bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

void main() {
  group('Asn1Reader', () {
    test('reads a simple INTEGER', () {
      // Tag 0x02, length 1, value 5
      final reader = Asn1Reader(_hex('0201 05'));
      final value = reader.readInteger();
      expect(value, BigInt.from(5));
      expect(reader.hasMore, isFalse);
    });

    test('reads a multi-byte INTEGER', () {
      // 0x0100 = 256
      final reader = Asn1Reader(_hex('0202 0100'));
      final value = reader.readInteger();
      expect(value, BigInt.from(256));
    });

    test('reads a negative INTEGER', () {
      // 0xFF = -1 in two's complement (1 byte)
      final reader = Asn1Reader(_hex('0201 FF'));
      final value = reader.readInteger();
      expect(value, BigInt.from(-1));
    });

    test('reads an OID (2.5.4.3 = CN)', () {
      // 2.5.4.3 -> 55 04 03
      final reader = Asn1Reader(_hex('0603 550403'));
      final oid = reader.readOid();
      expect(oid, '2.5.4.3');
    });

    test('reads an OID with multi-byte component', () {
      // 1.2.840.113549.1.1.11 (SHA256withRSA)
      // First byte = 1*40+2 = 42 = 0x2A
      // 840 = 0x348 -> 86 48
      // 113549 = 0x1BB8D -> 86 F7 0D
      // Then 01 01 0B
      final reader = Asn1Reader(_hex('0609 2A864886F70D01010B'));
      final oid = reader.readOid();
      expect(oid, '1.2.840.113549.1.1.11');
    });

    test('reads a PrintableString', () {
      // "US" as PrintableString
      final reader = Asn1Reader(_hex('1302 5553'));
      final value = reader.readString();
      expect(value, 'US');
    });

    test('reads a UTF8String', () {
      // "Test" as UTF8String
      final reader = Asn1Reader(_hex('0C04 54657374'));
      final value = reader.readString();
      expect(value, 'Test');
    });

    test('reads UTCTime', () {
      // "250101000000Z" as ASCII bytes
      final ascii = '250101000000Z'.codeUnits;
      final data = <int>[0x17, ascii.length, ...ascii];
      final reader = Asn1Reader(Uint8List.fromList(data));
      final dt = reader.readTime();
      expect(dt, DateTime.utc(2025));
    });

    test('reads GeneralizedTime', () {
      final ascii = '20300101120000Z'.codeUnits;
      final data = <int>[0x18, ascii.length, ...ascii];
      final reader = Asn1Reader(Uint8List.fromList(data));
      final dt = reader.readTime();
      expect(dt, DateTime.utc(2030, 1, 1, 12));
    });

    test('reads a SEQUENCE', () {
      // SEQUENCE { INTEGER 42, INTEGER 7 }
      final inner = _hex('0201 2A 0201 07');
      final seq = <int>[0x30, inner.length, ...inner];
      final reader = Asn1Reader(Uint8List.fromList(seq));
      final seqReader = reader.readSequence();
      expect(seqReader.readInteger(), BigInt.from(42));
      expect(seqReader.readInteger(), BigInt.from(7));
      expect(seqReader.hasMore, isFalse);
    });

    test('reads a BIT STRING', () {
      // BIT STRING: 0 unused bits, content 0xFF
      final reader = Asn1Reader(_hex('0302 00FF'));
      final bits = reader.readBitString();
      expect(bits, [0xFF]);
    });

    test('reads an OCTET STRING', () {
      final reader = Asn1Reader(_hex('0403 010203'));
      final octets = reader.readOctetString();
      expect(octets, [1, 2, 3]);
    });

    test('reads context tag', () {
      // Context [0] explicit, containing INTEGER 2
      // A0 03 02 01 02
      final reader = Asn1Reader(_hex('A003 020102'));
      final ctx = reader.readContextTag(0);
      expect(ctx, isNotNull);
      final value = ctx!.readInteger();
      expect(value, BigInt.from(2));
    });

    test('skipContextTag returns false when tag does not match', () {
      final reader = Asn1Reader(_hex('0201 05'));
      expect(reader.skipContextTag(0), isFalse);
      // Data should still be readable.
      expect(reader.readInteger(), BigInt.from(5));
    });

    test('handles multi-byte length (0x81)', () {
      // Construct a value with length 130 (0x82 bytes of 0x00)
      final value = List.filled(130, 0);
      final data = <int>[0x04, 0x81, 130, ...value];
      final reader = Asn1Reader(Uint8List.fromList(data));
      final octets = reader.readOctetString();
      expect(octets.length, 130);
    });

    test('handles multi-byte length (0x82)', () {
      final value = List.filled(300, 0xAA);
      final data = <int>[0x04, 0x82, 0x01, 0x2C, ...value];
      final reader = Asn1Reader(Uint8List.fromList(data));
      final octets = reader.readOctetString();
      expect(octets.length, 300);
    });

    test('throws on truncated data', () {
      final reader = Asn1Reader(_hex('0205 01'));
      expect(reader.readInteger, throwsFormatException);
    });

    test('throws on indefinite-length encoding', () {
      final reader = Asn1Reader(_hex('3080'));
      expect(reader.readSequence, throwsFormatException);
    });

    test('throws on wrong tag when expecting SEQUENCE', () {
      final reader = Asn1Reader(_hex('0201 05'));
      expect(reader.readSequence, throwsFormatException);
    });

    test('peekTag does not advance offset', () {
      final reader = Asn1Reader(_hex('0201 05'));
      expect(reader.peekTag(), 0x02);
      expect(reader.peekTag(), 0x02); // still the same
      expect(reader.readInteger(), BigInt.from(5));
    });

    test('readObject returns correct Asn1Object properties', () {
      final reader = Asn1Reader(_hex('0403 010203'));
      final obj = reader.readObject();
      expect(obj.tag, Asn1Tag.octetString);
      expect(obj.bytes, [1, 2, 3]);
      expect(obj.headerLength, 2);
      expect(obj.totalLength, 5);
      expect(obj.isConstructed, isFalse);
      expect(obj.isContextTag, isFalse);
    });

    test('isConstructed for SEQUENCE tag', () {
      final reader = Asn1Reader(_hex('3003 020105'));
      final obj = reader.readObject();
      expect(obj.isConstructed, isTrue);
    });

    test('context tag properties', () {
      final reader = Asn1Reader(_hex('A003 020105'));
      final obj = reader.readObject();
      expect(obj.isContextTag, isTrue);
      expect(obj.contextTagNumber, 0);
    });
  });
}
