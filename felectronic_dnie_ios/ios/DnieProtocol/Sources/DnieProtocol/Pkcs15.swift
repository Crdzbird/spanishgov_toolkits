import Foundation

/// Errors raised while decoding PKCS#15 card structures.
public enum Pkcs15Error: Error, Equatable, Sendable {
  case notASequence(tag: UInt32)
  case missingField(String)
  case malformed(String)
}

// MARK: - Path

/// A PKCS#15 `Path` — where on the card a value lives.
///
/// ```asn1
/// Path ::= SEQUENCE {
///   path   OCTET STRING,
///   index  INTEGER OPTIONAL,
///   length [0] INTEGER OPTIONAL
/// }
/// ```
///
/// Transcribed from `asn1/der/pkcs15/Path.m`, which declares exactly these
/// three elements with the last two optional.
public struct Pkcs15Path: Equatable, Sendable {
  /// File identifiers, most significant byte first — e.g. `[0x3F, 0x00]`.
  public let path: [UInt8]
  public let index: Int?
  public let length: Int?

  public init(path: [UInt8], index: Int? = nil, length: Int? = nil) {
    self.path = path
    self.index = index
    self.length = length
  }

  /// Path rendered as hex, the form jmulticard's `getPath()` returns.
  public var hexPath: String {
    path.map { String(format: "%02X", $0) }.joined()
  }

  /// The path split into two-byte file identifiers.
  public var fileIds: [[UInt8]] {
    stride(from: 0, to: path.count - path.count % 2, by: 2).map {
      Array(path[$0..<($0 + 2)])
    }
  }

  public static func decode(_ tlv: BerTlv) throws -> Pkcs15Path {
    let items = try tlv.children()
    guard let first = items.first, first.tagValue == Asn1.octetString else {
      throw Pkcs15Error.missingField("Path.path")
    }
    var index: Int?
    var length: Int?
    for item in items.dropFirst() {
      switch item.tagValue {
      case Asn1.integer where index == nil:
        index = Asn1.integerValue(item.value)
      case 0x80, Asn1.integer:  // [0] length, or a second INTEGER
        length = Asn1.integerValue(item.value)
      default:
        break  // unknown trailing elements are tolerated, as in the Java
      }
    }
    return Pkcs15Path(path: first.value, index: index, length: length)
  }
}

// MARK: - Certificate Directory File

/// One entry of the CDF: a certificate stored on the card.
public struct Pkcs15Certificate: Equatable, Sendable {
  /// `commonObjectAttributes.label` — the alias jmulticard reports.
  public let label: String?
  /// `classAttributes.iD` — pairs a certificate with its private key.
  public let identifier: [UInt8]
  /// Where the certificate bytes live.
  public let path: Pkcs15Path
}

/// PKCS#15 Certificate Directory File — a `SEQUENCE OF CertificateObject`.
///
/// ```asn1
/// CertificateObject ::= SEQUENCE {
///   commonObjectAttributes  SEQUENCE,   -- label, flags, authId
///   classAttributes         SEQUENCE,   -- iD
///   [1] typeAttributes      SEQUENCE    -- value (Path), subject, issuer, serial
/// }
/// ```
public struct Pkcs15Cdf: Equatable, Sendable {
  public let certificates: [Pkcs15Certificate]

  public var count: Int { certificates.count }

  /// Decodes a CDF from raw file contents.
  ///
  /// The file holds a run of certificate objects. Trailing padding — cards
  /// commonly pad with `0x00` or `0xFF` — ends parsing rather than failing,
  /// matching how the Java stops at the first unreadable record.
  public static func decode(_ bytes: [UInt8]) throws -> Pkcs15Cdf {
    var out: [Pkcs15Certificate] = []
    var offset = 0

    while offset < bytes.count {
      if Asn1.isPadding(bytes[offset]) { break }
      guard let tlv = try? BerTlv.decode(bytes, at: offset) else { break }
      guard tlv.endOffset > offset else { break }
      if tlv.isConstructed, let cert = try? decodeCertificateObject(tlv) {
        out.append(cert)
      }
      offset = tlv.endOffset
    }

    return Pkcs15Cdf(certificates: out)
  }

  static func decodeCertificateObject(_ tlv: BerTlv) throws -> Pkcs15Certificate {
    let parts = try tlv.children()
    guard parts.count >= 2 else {
      throw Pkcs15Error.malformed("CertificateObject needs at least two elements")
    }

    let label = try Asn1.firstUtf8String(in: parts[0])

    guard let idTlv = try parts[1].first(tag: Asn1.octetString) else {
      throw Pkcs15Error.missingField("CommonCertificateAttributes.iD")
    }

    // typeAttributes is context-tag [1]; its Path is the first inner SEQUENCE
    // containing an OCTET STRING.
    guard let type = parts.count > 2 ? parts[2] : nil,
          let pathTlv = try Asn1.firstSequenceContainingOctetString(type)
    else {
      throw Pkcs15Error.missingField("X509CertificateAttributes.value (Path)")
    }

    return Pkcs15Certificate(
      label: label,
      identifier: idTlv.value,
      path: try Pkcs15Path.decode(pathTlv)
    )
  }
}

// MARK: - Private Key Directory File

/// One entry of the PrKDF: a private key usable for signing.
public struct Pkcs15PrivateKey: Equatable, Sendable {
  public let label: String?
  /// `commonKeyAttributes.iD` — matches the certificate's identifier.
  public let identifier: [UInt8]
  /// `commonKeyAttributes.keyReference` — the value sent in MSE SET.
  public let keyReference: Int?
  public let path: Pkcs15Path?
}

/// PKCS#15 Private Key Directory File — a `SEQUENCE OF PrivateKeyObject`.
///
/// ```asn1
/// PrivateKeyObject ::= SEQUENCE {
///   commonObjectAttributes  SEQUENCE,   -- label
///   commonKeyAttributes     SEQUENCE,   -- iD, usage, native, accessFlags, keyReference
///   [1] typeAttributes      SEQUENCE    -- value (Path), modulusLength
/// }
/// ```
public struct Pkcs15PrKdf: Equatable, Sendable {
  public let keys: [Pkcs15PrivateKey]

  public var count: Int { keys.count }

  /// Finds the key sharing an identifier with a certificate — how a signing
  /// certificate is paired with the key that signs for it.
  public func key(matching certificate: Pkcs15Certificate) -> Pkcs15PrivateKey? {
    keys.first { $0.identifier == certificate.identifier }
  }

  public static func decode(_ bytes: [UInt8]) throws -> Pkcs15PrKdf {
    var out: [Pkcs15PrivateKey] = []
    var offset = 0

    while offset < bytes.count {
      if Asn1.isPadding(bytes[offset]) { break }
      guard let tlv = try? BerTlv.decode(bytes, at: offset) else { break }
      guard tlv.endOffset > offset else { break }
      if tlv.isConstructed, let key = try? decodePrivateKeyObject(tlv) {
        out.append(key)
      }
      offset = tlv.endOffset
    }

    return Pkcs15PrKdf(keys: out)
  }

  static func decodePrivateKeyObject(_ tlv: BerTlv) throws -> Pkcs15PrivateKey {
    let parts = try tlv.children()
    guard parts.count >= 2 else {
      throw Pkcs15Error.malformed("PrivateKeyObject needs at least two elements")
    }

    let label = try Asn1.firstUtf8String(in: parts[0])

    let keyAttrs = try parts[1].children()
    guard let idTlv = keyAttrs.first(where: { $0.tagValue == Asn1.octetString }) else {
      throw Pkcs15Error.missingField("CommonKeyAttributes.iD")
    }

    // keyReference is the last INTEGER in commonKeyAttributes; earlier
    // INTEGERs, when present, belong to other optional fields.
    let keyReference = keyAttrs
      .last { $0.tagValue == Asn1.integer }
      .map { Asn1.integerValue($0.value) }

    var path: Pkcs15Path?
    if parts.count > 2,
       let pathTlv = try Asn1.firstSequenceContainingOctetString(parts[2]) {
      path = try Pkcs15Path.decode(pathTlv)
    }

    return Pkcs15PrivateKey(
      label: label,
      identifier: idTlv.value,
      keyReference: keyReference,
      path: path
    )
  }
}

// MARK: - Shared ASN.1 helpers

enum Asn1 {
  static let integer: UInt32 = 0x02
  static let bitString: UInt32 = 0x03
  static let octetString: UInt32 = 0x04
  static let utf8String: UInt32 = 0x0C
  static let sequence: UInt32 = 0x30

  /// Cards pad directory files with 0x00 or 0xFF; either ends a record run.
  static func isPadding(_ byte: UInt8) -> Bool { byte == 0x00 || byte == 0xFF }

  /// Big-endian, unsigned. Key references and lengths are small positive
  /// values, so sign handling is deliberately not modelled here.
  static func integerValue(_ bytes: [UInt8]) -> Int {
    bytes.reduce(0) { ($0 << 8) | Int($1) }
  }

  static func firstUtf8String(in tlv: BerTlv) throws -> String? {
    guard let hit = try tlv.first(tag: utf8String) else { return nil }
    return String(bytes: hit.value, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Finds the first SEQUENCE whose immediate children include an OCTET
  /// STRING — the shape of a PKCS#15 `Path` wherever it is nested.
  static func firstSequenceContainingOctetString(_ tlv: BerTlv) throws -> BerTlv? {
    if tlv.tagValue == sequence {
      let kids = try tlv.children()
      if kids.first?.tagValue == octetString { return tlv }
    }
    for child in try tlv.children() {
      if let hit = try firstSequenceContainingOctetString(child) { return hit }
    }
    return nil
  }
}
