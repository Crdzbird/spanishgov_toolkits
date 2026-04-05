/// ASN.1 DER tag constants.
abstract final class Asn1Tag {
  /// BOOLEAN (0x01).
  static const int boolean = 0x01;

  /// INTEGER (0x02).
  static const int integer = 0x02;

  /// BIT STRING (0x03).
  static const int bitString = 0x03;

  /// OCTET STRING (0x04).
  static const int octetString = 0x04;

  /// NULL (0x05).
  static const int null_ = 0x05;

  /// OBJECT IDENTIFIER (0x06).
  static const int oid = 0x06;

  /// UTF8String (0x0C).
  static const int utf8String = 0x0C;

  /// SEQUENCE (0x30).
  static const int sequence = 0x30;

  /// SET (0x31).
  static const int set_ = 0x31;

  /// PrintableString (0x13).
  static const int printableString = 0x13;

  /// T61String / TeletexString (0x14).
  static const int t61String = 0x14;

  /// IA5String (0x16).
  static const int ia5String = 0x16;

  /// UTCTime (0x17).
  static const int utcTime = 0x17;

  /// GeneralizedTime (0x18).
  static const int generalizedTime = 0x18;

  /// BMPString (0x1E).
  static const int bmpString = 0x1E;

  /// Constructed flag (0x20).
  static const int constructed = 0x20;

  /// Context-specific tag [0] (0xA0).
  static const int contextTag0 = 0xA0;

  /// Context-specific tag [1] (0xA1).
  static const int contextTag1 = 0xA1;

  /// Context-specific tag [2] (0xA2).
  static const int contextTag2 = 0xA2;

  /// Context-specific tag [3] (0xA3).
  static const int contextTag3 = 0xA3;
}
