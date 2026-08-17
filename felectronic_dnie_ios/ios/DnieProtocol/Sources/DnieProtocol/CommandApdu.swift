import Foundation

/// A command APDU (ISO 7816-4), encoded exactly as jmulticard encodes it.
///
/// Ported from `es.gob.jmulticard.apdu.CommandApdu`. The encoding below is a
/// direct transcription of that constructor, including two deliberate quirks
/// that are preserved because the Android build of the same library is known
/// to work against real cards:
///
/// 1. **An empty (but non-nil) data field still emits `Lc = 0x00`.** jmulticard
///    writes the length byte before checking whether the body is non-empty, so
///    `data: []` produces a different encoding from `data: nil`.
/// 2. **Extended `Le` is written as two bytes, not three.** ISO 7816-4 requires
///    a `0x00` prefix when there is no extended `Lc` preceding it; jmulticard
///    always writes just the high and low bytes. Preserved to match, and
///    unreachable in the DNIe flows, which never use extended `Le`.
///
/// - SeeAlso: `jmulticard-objc/es/gob/jmulticard/apdu/CommandApdu.m`
public struct CommandApdu: Equatable, Sendable {
  public let cla: UInt8
  public let ins: UInt8
  public let p1: UInt8
  public let p2: UInt8

  /// Command data field. `nil` and `[]` encode differently — see the type doc.
  public let data: [UInt8]?

  /// Expected response length. `nil` omits the `Le` byte entirely.
  public let le: Int?

  public init(
    cla: UInt8,
    ins: UInt8,
    p1: UInt8,
    p2: UInt8,
    data: [UInt8]? = nil,
    le: Int? = nil
  ) {
    self.cla = cla
    self.ins = ins
    self.p1 = p1
    self.p2 = p2
    self.data = data
    self.le = le
  }

  /// The wire encoding sent to the card.
  public var bytes: [UInt8] {
    var out: [UInt8] = [cla, ins, p1, p2]

    if let data {
      if data.count <= 255 {
        // Note: emitted even when count == 0, matching jmulticard.
        out.append(UInt8(truncatingIfNeeded: data.count))
      } else {
        out.append(0x00)
        out.append(UInt8(truncatingIfNeeded: data.count >> 8))
        out.append(UInt8(truncatingIfNeeded: data.count))
      }
      if !data.isEmpty {
        out.append(contentsOf: data)
      }
    }

    if let le {
      if le <= 0xFF {
        out.append(UInt8(truncatingIfNeeded: le))
      } else {
        out.append(UInt8(truncatingIfNeeded: le >> 8))
        out.append(UInt8(truncatingIfNeeded: le))
      }
    }

    return out
  }

  /// Convenience for callers working in `Data`.
  public var encoded: Data { Data(bytes) }
}

extension CommandApdu: CustomStringConvertible {
  public var description: String {
    bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
  }
}
