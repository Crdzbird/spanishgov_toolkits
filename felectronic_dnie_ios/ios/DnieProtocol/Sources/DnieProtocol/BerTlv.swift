import Foundation

/// Errors raised while decoding BER-TLV.
public enum BerTlvError: Error, Equatable, Sendable {
  case truncated(atOffset: Int)
  case unsupportedLengthForm(firstByte: UInt8, atOffset: Int)
  case lengthOverflow(atOffset: Int)
}

/// A single BER-TLV object, decoded per X.690.
///
/// ## Relationship to `es.gob.jmulticard.asn1.Tlv`
///
/// That class decodes lengths exactly as BER specifies — short form below
/// `0x80`, long form for `0x81`–`0x83`, and the indefinite form at `0x80`,
/// which it accepts only for constructed tags. This decoder agrees with it on
/// every length encoding, and differs in two narrow ways:
///
/// 1. **Multi-byte tags.** jmulticard reads a single tag byte, so a tag whose
///    low five bits are all set (`0x1F`, e.g. `7F 49` for a CVC public key)
///    would be misparsed. This decoder follows X.690 8.1.2 and reads the
///    continuation bytes. That matters from Stage 3 onward, where card
///    verifiable certificates use exactly those tags.
/// 2. **Indefinite length is rejected here.** jmulticard permits it for
///    constructed tags; card structures are DER, where it is illegal, so
///    treating it as an error surfaces malformed data instead of guessing at
///    where the value ends.
///
/// An earlier revision of this file claimed jmulticard's length handling was
/// non-standard. That was a misreading of the transpiled source — two
/// unrelated branches read as one — and the claim was wrong. Recorded here
/// because the mistaken version was committed, and someone comparing the two
/// implementations deserves the accurate account.
///
/// Stage 2 validates this decoder against real PKCS#15 structures.
public struct BerTlv: Equatable, Sendable {
  /// The full tag, including multi-byte tags, most significant byte first.
  public let tag: [UInt8]

  /// The value bytes.
  public let value: [UInt8]

  /// Offset just past this object in the buffer it was decoded from.
  public let endOffset: Int

  public init(tag: [UInt8], value: [UInt8], endOffset: Int = 0) {
    self.tag = tag
    self.value = value
    self.endOffset = endOffset
  }

  /// The tag as an integer, for comparison against literals like `0x6F`.
  public var tagValue: UInt32 {
    tag.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
  }

  /// Whether the tag's constructed bit is set, meaning `value` holds more TLVs.
  public var isConstructed: Bool {
    (tag.first ?? 0) & 0x20 != 0
  }

  /// Decodes one TLV starting at `offset`.
  public static func decode(_ bytes: [UInt8], at offset: Int = 0) throws -> BerTlv {
    var i = offset
    guard i < bytes.count else { throw BerTlvError.truncated(atOffset: i) }

    // --- Tag: low 5 bits all set means the tag continues into further bytes,
    // each of which sets bit 7 while more follow (X.690 8.1.2).
    var tag: [UInt8] = [bytes[i]]
    if bytes[i] & 0x1F == 0x1F {
      repeat {
        i += 1
        guard i < bytes.count else { throw BerTlvError.truncated(atOffset: i) }
        tag.append(bytes[i])
      } while bytes[i] & 0x80 != 0
    }
    i += 1

    // --- Length: short form is a single byte < 0x80; long form encodes the
    // byte-count of the length in the low 7 bits. 0x80 (indefinite) is not
    // valid in DER and is not accepted here.
    guard i < bytes.count else { throw BerTlvError.truncated(atOffset: i) }
    let first = bytes[i]
    i += 1

    var length = 0
    if first & 0x80 == 0 {
      length = Int(first)
    } else {
      let count = Int(first & 0x7F)
      guard count > 0, count <= 4 else {
        throw BerTlvError.unsupportedLengthForm(firstByte: first, atOffset: i - 1)
      }
      guard i + count <= bytes.count else { throw BerTlvError.truncated(atOffset: i) }
      for _ in 0..<count {
        length = (length << 8) | Int(bytes[i])
        i += 1
      }
    }

    guard length >= 0, i + length <= bytes.count else {
      throw BerTlvError.truncated(atOffset: i)
    }

    return BerTlv(
      tag: tag,
      value: Array(bytes[i..<(i + length)]),
      endOffset: i + length
    )
  }

  /// Decodes every TLV in `bytes`, in order.
  public static func decodeAll(_ bytes: [UInt8]) throws -> [BerTlv] {
    var out: [BerTlv] = []
    var offset = 0
    while offset < bytes.count {
      let tlv = try decode(bytes, at: offset)
      out.append(tlv)
      guard tlv.endOffset > offset else { break }  // defensive: never loop forever
      offset = tlv.endOffset
    }
    return out
  }

  /// Decodes the children of a constructed TLV.
  public func children() throws -> [BerTlv] {
    guard isConstructed else { return [] }
    return try BerTlv.decodeAll(value)
  }

  /// Depth-first search for the first descendant (or self) with `tag`.
  public func first(tag wanted: UInt32) throws -> BerTlv? {
    if tagValue == wanted { return self }
    for child in try children() {
      if let hit = try child.first(tag: wanted) { return hit }
    }
    return nil
  }

  /// The canonical encoding of this object.
  public var encoded: [UInt8] {
    var out = tag
    let n = value.count
    if n < 0x80 {
      out.append(UInt8(n))
    } else {
      var lengthBytes: [UInt8] = []
      var remaining = n
      while remaining > 0 {
        lengthBytes.insert(UInt8(remaining & 0xFF), at: 0)
        remaining >>= 8
      }
      out.append(0x80 | UInt8(lengthBytes.count))
      out.append(contentsOf: lengthBytes)
    }
    out.append(contentsOf: value)
    return out
  }
}
