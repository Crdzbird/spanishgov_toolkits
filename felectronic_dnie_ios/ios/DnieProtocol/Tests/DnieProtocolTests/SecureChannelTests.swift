import XCTest
@testable import DnieProtocol

/// The deterministic half of CWA-14890: key derivation, the send sequence
/// counter, and secure-messaging framing.
///
/// **What these tests prove.** Each expectation is either a SHA-1 vector
/// computed outside this code, or a byte layout read directly off the
/// transpiled Java that the working Android build runs. They prove the
/// functions compute what the protocol specifies.
///
/// **What they do not prove.** Nothing here talks to a card. The values fed in
/// — the shared seed, the two challenges — come from the authentication
/// exchange, which is not implemented and cannot be exercised without a
/// physical DNIe and a reader. Correct functions over untested inputs are
/// still an untested channel.
final class SecureChannelTests: XCTestCase {

  private func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
  }

  // MARK: - Key derivation

  /// Vectors computed with Python's `hashlib`, independently of the
  /// implementation under test:
  ///
  /// ```python
  /// hashlib.sha1(bytes([0xAA]*32) + bytes([0,0,0,1])).hexdigest()[:32]
  /// ```
  func testDerivedKeysMatchIndependentSha1Vectors() {
    let uniform = [UInt8](repeating: 0xAA, count: 32)
    XCTAssertEqual(
      hex(Cwa14890KeyDerivation.encryptionKey(seed: uniform)),
      "d8e34904ccd7321cb607e272d29c48a1"
    )
    XCTAssertEqual(
      hex(Cwa14890KeyDerivation.macKey(seed: uniform)),
      "2ef977d7a90ac25d570dbbabe497e08d"
    )

    let counting = (0..<32).map(UInt8.init)
    XCTAssertEqual(
      hex(Cwa14890KeyDerivation.encryptionKey(seed: counting)),
      "a98ffb7caef3bd518fb7bc1b6cc89dbd"
    )
    XCTAssertEqual(
      hex(Cwa14890KeyDerivation.macKey(seed: counting)),
      "e6b6e6b5e405eb5e6ffb080c390c2cd8"
    )
  }

  func testKeysAre16BytesNotTheFullDigest() {
    let seed = [UInt8](repeating: 0x5A, count: 32)
    XCTAssertEqual(Cwa14890KeyDerivation.encryptionKey(seed: seed).count, 16)
    XCTAssertEqual(Cwa14890KeyDerivation.macKey(seed: seed).count, 16)
  }

  /// The counters are what separate the two keys; if they were ever equal the
  /// channel would encrypt and authenticate under one key.
  func testEncryptionAndMacKeysDifferForTheSameSeed() {
    let seed = [UInt8](repeating: 0x11, count: 32)
    XCTAssertNotEqual(
      Cwa14890KeyDerivation.encryptionKey(seed: seed),
      Cwa14890KeyDerivation.macKey(seed: seed)
    )
    XCTAssertEqual(Cwa14890KeyDerivation.encryptionCounter, [0x00, 0x00, 0x00, 0x01])
    XCTAssertEqual(Cwa14890KeyDerivation.macCounter, [0x00, 0x00, 0x00, 0x02])
  }

  // MARK: - Send sequence counter seeding

  /// `SSC = randomIcc[4..8] ‖ randomIfd[4..8]` — the card's half leads.
  func testCounterTakesTheCardsHalfFirst() throws {
    let ifd: [UInt8] = [0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17]
    let icc: [UInt8] = [0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27]

    let ssc = try SendSequenceCounter(randomIfd: ifd, randomIcc: icc)
    XCTAssertEqual(ssc.bytes, [0x24, 0x25, 0x26, 0x27, 0x14, 0x15, 0x16, 0x17])
  }

  /// Swapping the challenges must change the counter — a guard against the
  /// two arguments being transposed at a call site, which no type check would
  /// catch and which would break every MAC.
  func testSwappingChallengesYieldsADifferentCounter() throws {
    let a: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]
    let b: [UInt8] = [0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8]
    XCTAssertNotEqual(
      try SendSequenceCounter(randomIfd: a, randomIcc: b).bytes,
      try SendSequenceCounter(randomIfd: b, randomIcc: a).bytes
    )
  }

  func testShortChallengesAreRejected() {
    let ok = [UInt8](repeating: 0, count: 8)
    XCTAssertThrowsError(try SendSequenceCounter(randomIfd: [0x00], randomIcc: ok)) {
      XCTAssertEqual($0 as? SecureChannelError, .badChallengeLength(role: "IFD", actual: 1))
    }
    XCTAssertThrowsError(try SendSequenceCounter(randomIfd: ok, randomIcc: [])) {
      XCTAssertEqual($0 as? SecureChannelError, .badChallengeLength(role: "ICC", actual: 0))
    }
  }

  func testInitRejectsWrongWidthRatherThanPadding() {
    XCTAssertNil(SendSequenceCounter(bytes: [0x01, 0x02]))
    XCTAssertNil(SendSequenceCounter(bytes: [UInt8](repeating: 0, count: 9)))
    XCTAssertNotNil(SendSequenceCounter(bytes: [UInt8](repeating: 0, count: 8)))
  }

  // MARK: - Send sequence counter increment

  func testIncrementIsBigEndian() {
    var ssc = SendSequenceCounter(bytes: [0, 0, 0, 0, 0, 0, 0, 0])!
    ssc.increment()
    XCTAssertEqual(ssc.bytes, [0, 0, 0, 0, 0, 0, 0, 1])
  }

  func testCarryPropagatesAcrossByteBoundaries() {
    var ssc = SendSequenceCounter(bytes: [0, 0, 0, 0, 0, 0, 0x00, 0xFF])!
    ssc.increment()
    XCTAssertEqual(ssc.bytes, [0, 0, 0, 0, 0, 0, 0x01, 0x00])

    var deep = SendSequenceCounter(bytes: [0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])!
    deep.increment()
    XCTAssertEqual(deep.bytes, [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
  }

  /// `BigInteger.toByteArray()` emits a leading `0x00` once the high bit is
  /// set; the Java drops it by keeping the last 8 bytes. The counter must stay
  /// 8 bytes wide across that boundary.
  func testHighBitSetDoesNotGainASignByte() {
    var ssc = SendSequenceCounter(bytes: [0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])!
    ssc.increment()
    XCTAssertEqual(ssc.bytes.count, 8)
    XCTAssertEqual(ssc.bytes, [0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
  }

  /// The other edge of the same argument: 2^64 encodes as nine bytes, and
  /// keeping the last eight gives zero.
  func testWrapsAtMaximum() {
    var ssc = SendSequenceCounter(bytes: [UInt8](repeating: 0xFF, count: 8))!
    ssc.increment()
    XCTAssertEqual(ssc.bytes, [UInt8](repeating: 0x00, count: 8))
  }

  func testIncrementedLeavesTheOriginalAlone() {
    let ssc = SendSequenceCounter(bytes: [0, 0, 0, 0, 0, 0, 0, 7])!
    XCTAssertEqual(ssc.incremented().bytes.last, 8)
    XCTAssertEqual(ssc.bytes.last, 7)
  }

  /// Each exchange advances the counter twice — once for the command, once for
  /// the response. Ten exchanges therefore land on twenty, not ten.
  func testTwoAdvancesPerExchange() {
    var ssc = SendSequenceCounter(bytes: [0, 0, 0, 0, 0, 0, 0, 0])!
    for _ in 0..<10 {
      ssc.increment()  // before protecting the command
      ssc.increment()  // before decrypting the response
    }
    XCTAssertEqual(ssc.bytes, [0, 0, 0, 0, 0, 0, 0, 20])
  }

  // MARK: - Cryptographic checksum framing

  func testChecksumIsAppendedAsTag8E() throws {
    let data: [UInt8] = [0x87, 0x02, 0x01, 0xAA]
    let mac: [UInt8] = [0x11, 0x22, 0x33, 0x44]
    XCTAssertEqual(
      try SecureMessaging.appendingChecksum(to: data, mac: mac),
      [0x87, 0x02, 0x01, 0xAA, 0x8E, 0x04, 0x11, 0x22, 0x33, 0x44]
    )
  }

  func testEightByteChecksumIsAccepted() throws {
    let mac = [UInt8](repeating: 0xEE, count: 8)
    let out = try SecureMessaging.appendingChecksum(to: [], mac: mac)
    XCTAssertEqual(out, [0x8E, 0x08] + mac)
  }

  /// A MAC of any other width is rejected rather than framed. Truncating a MAC
  /// silently weakens the channel, so this is a real check and not a formality.
  func testOtherChecksumLengthsAreRejected() {
    for count in [0, 1, 3, 5, 7, 16] {
      XCTAssertThrowsError(
        try SecureMessaging.appendingChecksum(
          to: [], mac: [UInt8](repeating: 0, count: count)
        ),
        "a \(count)-byte MAC should not be accepted"
      ) {
        XCTAssertEqual($0 as? SecureChannelError, .badChecksumLength(actual: count))
      }
    }
  }

  // MARK: - Response classification

  func testInvalidChecksumIsFatal() {
    XCTAssertEqual(
      StatusWord(sw1: 0x66, sw2: 0x88).secureMessagingOutcome,
      .fail(.invalidCryptographicChecksum)
    )
  }

  /// `6C xx` carries the correct length; `62 xx` does not, and steps down.
  func testTheTwoWrongLengthSignalsAreHandledDifferently() {
    XCTAssertEqual(StatusWord(sw1: 0x6C, sw2: 0x1F).secureMessagingOutcome, .resend(le: 0x1F))
    XCTAssertEqual(StatusWord(sw1: 0x62, sw2: 0x1F).secureMessagingOutcome, .resendWithOneLessByte)
  }

  /// Documents the deliberate divergence from `StatusWord.wrongLe`, which maps
  /// a zero length to 256 per ISO 7816-4. The Java does not, and this follows
  /// the Java.
  func testZeroLengthIsPassedThroughRawUnlikeWrongLe() {
    XCTAssertEqual(StatusWord(sw1: 0x6C, sw2: 0x00).secureMessagingOutcome, .resend(le: 0))
    XCTAssertEqual(StatusWord(sw1: 0x6C, sw2: 0x00).wrongLe, 256)
  }

  func testSuccessAndUnrelatedErrorsAreAccepted() {
    XCTAssertEqual(StatusWord(sw1: 0x90, sw2: 0x00).secureMessagingOutcome, .accept)
    XCTAssertEqual(StatusWord(sw1: 0x69, sw2: 0x82).secureMessagingOutcome, .accept)
    // 66 xx other than 88 is not the checksum failure.
    XCTAssertEqual(StatusWord(sw1: 0x66, sw2: 0x00).secureMessagingOutcome, .accept)
  }
}
