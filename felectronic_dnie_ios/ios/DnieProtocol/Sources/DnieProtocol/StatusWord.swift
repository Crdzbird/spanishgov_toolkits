/// The two trailing status bytes (SW1, SW2) of a response APDU.
///
/// Ported from `es.gob.jmulticard.apdu.StatusWord`.
public struct StatusWord: Equatable, Hashable, Sendable {
  public let sw1: UInt8
  public let sw2: UInt8

  public init(sw1: UInt8, sw2: UInt8) {
    self.sw1 = sw1
    self.sw2 = sw2
  }

  /// The status word as a single 16-bit value, e.g. `0x9000`.
  public var value: UInt16 { UInt16(sw1) << 8 | UInt16(sw2) }

  /// `true` only for `90 00`.
  ///
  /// jmulticard's `isOk` is exactly this equality test — it does not treat
  /// `61 xx` (more data available) or `62/63 xx` (warnings) as success, and
  /// callers handle those explicitly. Kept identical so behaviour matches.
  public var isOk: Bool { sw1 == 0x90 && sw2 == 0x00 }

  /// `61 xx` — the card has `xx` more bytes; issue GET RESPONSE.
  public var hasMoreData: Bool { sw1 == 0x61 }

  /// For `61 xx`, the number of bytes still available (`0` meaning 256).
  public var remainingBytes: Int? { sw1 == 0x61 ? (sw2 == 0 ? 256 : Int(sw2)) : nil }

  /// `6C xx` — wrong Le; retry with `xx` as Le.
  public var wrongLe: Int? { sw1 == 0x6C ? (sw2 == 0 ? 256 : Int(sw2)) : nil }
}

extension StatusWord: CustomStringConvertible {
  public var description: String {
    String(format: "%02X%02X", sw1, sw2)
  }
}
