import Foundation

/// The CWA-14890 Send Sequence Counter.
///
/// An 8-byte counter mixed into every secure-messaging MAC. It is incremented
/// **twice per exchange** — once before protecting the command, once before
/// decrypting the response — which is what binds each cryptogram to its
/// position in the conversation and stops an attacker replaying or reordering
/// APDUs. Losing sync with the card is unrecoverable: every subsequent MAC
/// fails.
///
/// ## Seeding
///
/// From `Cwa14890OneV1Connection.generateSsc`:
///
/// ```objc
/// IOSByteArray *ssc = [IOSByteArray arrayWithLength:8];
/// arraycopy(randomIcc, 4, ssc, 0, 4);   // last 4 bytes of the card's random
/// arraycopy(randomIfd, 4, ssc, 4, 4);   // last 4 bytes of the terminal's random
/// ```
///
/// Note the ordering: the **card's** half comes first. Both randoms are the
/// 8-byte challenges exchanged during authentication.
///
/// ## Increment
///
/// The Java is `new BigInteger(1, ssc).add(BigInteger.ONE)`, re-normalised to
/// 8 bytes — right-truncated when the result is longer, left-padded when
/// shorter. Over an 8-byte value that is exactly an unsigned big-endian
/// increment with wraparound at 2^64, which is how it is expressed here:
///
/// - A value with the high bit set makes `BigInteger.toByteArray()` emit a
///   leading sign byte, giving 9 bytes; taking the last 8 discards it.
/// - `FF FF FF FF FF FF FF FF + 1` is 2^64, encoded as 9 bytes; taking the
///   last 8 yields all zeros.
///
/// Both cases fall out of `UInt64` wrapping addition, so the behaviours agree
/// byte for byte. `testWrapsAtMaximum` and `testHighBitSetDoesNotGainASignByte`
/// pin the two edges the reasoning turns on.
public struct SendSequenceCounter: Equatable, Sendable {

  /// Fixed width of the counter, in bytes.
  public static let length = 8

  private var counter: UInt64

  /// The counter as 8 bytes, most significant first — the form fed to the MAC.
  public var bytes: [UInt8] {
    (0..<Self.length).reversed().map { UInt8((counter >> (8 * UInt64($0))) & 0xFF) }
  }

  /// Builds a counter from the challenges exchanged during authentication.
  ///
  /// Both challenges must be 8 bytes; only their trailing halves are used.
  public init(randomIfd: [UInt8], randomIcc: [UInt8]) throws {
    guard randomIfd.count == 8 else {
      throw SecureChannelError.badChallengeLength(role: "IFD", actual: randomIfd.count)
    }
    guard randomIcc.count == 8 else {
      throw SecureChannelError.badChallengeLength(role: "ICC", actual: randomIcc.count)
    }
    self.init(bytes: Array(randomIcc.suffix(4)) + Array(randomIfd.suffix(4)))!
  }

  /// Builds a counter from an explicit 8-byte value. Returns `nil` for any
  /// other length rather than silently padding.
  public init?(bytes: [UInt8]) {
    guard bytes.count == Self.length else { return nil }
    counter = bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
  }

  /// Advances the counter by one, wrapping at 2^64.
  public mutating func increment() {
    counter &+= 1
  }

  /// The counter advanced by one, leaving the receiver untouched.
  public func incremented() -> SendSequenceCounter {
    var next = self
    next.increment()
    return next
  }
}

/// Errors raised while establishing or driving the secure channel.
public enum SecureChannelError: Error, Equatable, Sendable {
  /// A challenge was not the 8 bytes the protocol requires.
  case badChallengeLength(role: String, actual: Int)
  /// A cryptographic checksum was not 4 or 8 bytes.
  case badChecksumLength(actual: Int)
  /// The card reported that the MAC it computed did not match ours.
  case invalidCryptographicChecksum
}
