import Foundation

/// A response APDU: payload bytes followed by a two-byte status word.
///
/// Ported from `es.gob.jmulticard.apdu.ResponseApdu`.
public struct ResponseApdu: Equatable, Sendable {
  /// The full response as received, status word included.
  public let bytes: [UInt8]

  /// The pre-decryption bytes, when the response arrived over a secure
  /// channel. Carried through for logging and for the secure-messaging layer
  /// (Stage 3); `nil` for plaintext exchanges.
  public let encryptedBytes: [UInt8]?

  public init(bytes: [UInt8], encryptedBytes: [UInt8]? = nil) {
    self.bytes = bytes
    self.encryptedBytes = encryptedBytes
  }

  public init(_ data: Data, encryptedBytes: Data? = nil) {
    self.init(bytes: [UInt8](data), encryptedBytes: encryptedBytes.map { [UInt8]($0) })
  }

  /// The status word, or `nil` if the response is too short to contain one.
  ///
  /// jmulticard logs a warning and returns null here rather than throwing;
  /// an Optional carries the same meaning without the side effect.
  public var statusWord: StatusWord? {
    guard bytes.count >= 2 else { return nil }
    return StatusWord(sw1: bytes[bytes.count - 2], sw2: bytes[bytes.count - 1])
  }

  /// The payload — everything before the status word.
  ///
  /// Returns empty rather than trapping on a short response; jmulticard would
  /// throw a negative-array-size exception for inputs under two bytes.
  public var data: [UInt8] {
    guard bytes.count > 2 else { return [] }
    return Array(bytes[..<(bytes.count - 2)])
  }

  /// `true` only when the status word is `90 00`.
  public var isOk: Bool { statusWord?.isOk ?? false }
}

extension ResponseApdu: CustomStringConvertible {
  public var description: String {
    guard let sw = statusWord else {
      return "<malformed response, \(bytes.count) byte(s)>"
    }
    return "\(data.count) byte(s) + SW=\(sw)"
  }
}
