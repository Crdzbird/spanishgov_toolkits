import XCTest
@testable import DnieProtocol

/// Secure-messaging encryption, the retail MAC, and APDU wrapping.
///
/// **Verified here:** the DES and Triple DES primitives against published
/// vectors; the MAC against an independently computed CBC-MAC using a
/// degeneracy of the algorithm; every byte layout against the transpiled Java
/// that the working Android build runs.
///
/// **Not verified here, and not verifiable without hardware:** that a real
/// DNIe accepts any of it. The composition could be wrong in a way every test
/// below still passes — a MAC computed over the right bytes in the wrong order
/// is self-consistent. The failure mode on a card is `66 88` and a dead
/// channel, which is at least loud.
final class ApduEncrypterTests: XCTestCase {

  private func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
  }
  private func bytes(_ s: String) -> [UInt8] {
    stride(from: 0, to: s.count, by: 2).map {
      let i = s.index(s.startIndex, offsetBy: $0)
      return UInt8(s[i...s.index(i, offsetBy: 1)], radix: 16)!
    }
  }

  // MARK: - DES primitives, against published vectors

  /// The classic FIPS DES example. Cross-checked with `openssl`, which
  /// reproduces it via Triple DES with three identical keys.
  func testDesMatchesTheKnownAnswerVector() throws {
    XCTAssertEqual(
      hex(try Des.encryptBlock(bytes("0123456789abcdef"), key: bytes("133457799bbcdff1"))),
      "85e813540f0ab405"
    )
    XCTAssertEqual(
      hex(try Des.encryptBlock(bytes("02468aceeca86420"), key: bytes("0f1571c947d9e859"))),
      "da02ce3a89ecac3b"
    )
  }

  /// Vector produced by `openssl enc -des-ede3-cbc -iv 0 -nopad`.
  func testTripleDesCbcMatchesOpenssl() throws {
    let key = bytes("0123456789abcdef23456789abcdef01")  // 16-byte two-key form
    let plain = bytes("00112233445566778899aabbccddeeff")
    let cipher = try TripleDes.encrypt(plain, key: key)
    XCTAssertEqual(hex(cipher), "d54bd4eb46750cd1db7a4ddf3db7f216")
    XCTAssertEqual(try TripleDes.decrypt(cipher, key: key), plain)
  }

  /// The 16-byte session keys are the two-key form; CommonCrypto needs 24.
  func testKeyExpansionIsK1K2K1() throws {
    let k16 = bytes("00112233445566778899aabbccddeeff")
    XCTAssertEqual(
      hex(try TripleDes.expandKey(k16)),
      "00112233445566778899aabbccddeeff0011223344556677"
    )
    let k24 = [UInt8](repeating: 0xAB, count: 24)
    XCTAssertEqual(try TripleDes.expandKey(k24), k24, "24-byte keys pass through")
    XCTAssertThrowsError(try TripleDes.expandKey([0x00]))
  }

  /// Triple DES with all three subkeys equal is single DES — a property that
  /// ties the two primitives together and would catch a key-ordering slip.
  func testTripleDesWithIdenticalKeysIsSingleDes() throws {
    let k = bytes("133457799bbcdff1")
    let block = bytes("0123456789abcdef")
    XCTAssertEqual(
      try TripleDes.encrypt(block, key: k + k),
      try Des.encryptBlock(block, key: k)
    )
  }

  func testMisalignedInputIsRejected() {
    XCTAssertThrowsError(
      try TripleDes.encrypt([0x01, 0x02], key: [UInt8](repeating: 0, count: 16))
    ) { XCTAssertEqual($0 as? DesError, .notBlockAligned(count: 2)) }
  }

  // MARK: - ISO 7816-4 padding

  /// Padding is always added — a block-aligned input gains a whole block.
  /// Without that the scheme would be ambiguous.
  func testAlignedInputStillGainsAFullBlock() {
    let aligned = [UInt8](repeating: 0xAA, count: 8)
    let padded = Iso7816Padding.add(aligned, blockSize: 8)
    XCTAssertEqual(padded.count, 16)
    XCTAssertEqual(Array(padded.suffix(8)), [0x80, 0, 0, 0, 0, 0, 0, 0])
  }

  func testPaddingRoundTrips() {
    for count in 0..<24 {
      let original = (0..<count).map { UInt8($0 &+ 1) }  // no 0x00 bytes
      let padded = Iso7816Padding.add(original, blockSize: 8)
      XCTAssertEqual(padded.count % 8, 0)
      XCTAssertEqual(Iso7816Padding.remove(padded), original, "failed at \(count)")
    }
  }

  func testEmptyInputPadsToOneBlockAndBack() {
    let padded = Iso7816Padding.add([], blockSize: 8)
    XCTAssertEqual(padded, [0x80, 0, 0, 0, 0, 0, 0, 0])
    XCTAssertEqual(Iso7816Padding.remove(padded), [])
  }

  /// Inherited from the Java: unpadded input comes back untouched rather than
  /// raising. Card responses are not always padded.
  func testUnpaddedInputIsReturnedUnchanged() {
    let unpadded: [UInt8] = [0x01, 0x02, 0x03, 0x04]
    XCTAssertEqual(Iso7816Padding.remove(unpadded), unpadded)
    let allZeros = [UInt8](repeating: 0, count: 8)
    XCTAssertEqual(Iso7816Padding.remove(allZeros), allZeros)
  }

  /// Data ending in 0x80 before padding is stripped correctly — the scan stops
  /// at the last 0x80, which is the padding marker, not the data byte.
  func testDataEndingIn0x80SurvivesTheRoundTrip() {
    let tricky: [UInt8] = [0x01, 0x80]
    XCTAssertEqual(Iso7816Padding.remove(Iso7816Padding.add(tricky, blockSize: 8)), tricky)
  }

  // MARK: - Retail MAC

  /// With `K1 == K2`, the final `E_K1(D_K2(E_K1(x)))` collapses to `E_K1(x)`,
  /// so Algorithm 3 becomes a plain DES CBC-MAC over `ssc ‖ data`. That value
  /// was computed with `openssl`, independently of this code, which checks the
  /// hand-rolled chaining rather than merely its self-consistency.
  func testMacDegeneratesToCbcMacAndMatchesOpenssl() throws {
    let k = bytes("0123456789abcdef")
    let ssc = bytes("0001020304050607")
    let data = bytes("a0a1a2a3a4a5a6a7b0b1b2b3b4b5b6b7")

    let full = ApduEncrypter(macLength: 8)
    XCTAssertEqual(
      hex(try full.mac(data: data, sendSequenceCounter: ssc, macKey: k + k)),
      "3e6943b38e912416"
    )
  }

  /// The V1 channel sends only the first four bytes of that same MAC.
  func testMacLengthTruncatesRatherThanRecomputes() throws {
    let k = bytes("0123456789abcdef")
    let ssc = bytes("0001020304050607")
    let data = bytes("a0a1a2a3a4a5a6a7b0b1b2b3b4b5b6b7")

    let short = try ApduEncrypter.des.mac(data: data, sendSequenceCounter: ssc, macKey: k + k)
    let long = try ApduEncrypter.desMac8.mac(data: data, sendSequenceCounter: ssc, macKey: k + k)
    XCTAssertEqual(short.count, 4)
    XCTAssertEqual(long.count, 8)
    XCTAssertEqual(short, Array(long.prefix(4)))
  }

  /// The counter is what binds a MAC to its position in the conversation. If
  /// this ever stopped mattering, replay protection would be gone.
  func testMacDependsOnTheSendSequenceCounter() throws {
    let key = [UInt8](repeating: 0x5A, count: 16)
    let data = [UInt8](repeating: 0x11, count: 16)
    let a = try ApduEncrypter.desMac8.mac(
      data: data, sendSequenceCounter: bytes("0000000000000001"), macKey: key)
    let b = try ApduEncrypter.desMac8.mac(
      data: data, sendSequenceCounter: bytes("0000000000000002"), macKey: key)
    XCTAssertNotEqual(a, b)
  }

  /// Algorithm 3's whole point is that the second key participates. If the
  /// final Triple DES step were dropped, this would pass anyway — hence the
  /// openssl-anchored test above, which would not.
  func testMacDependsOnTheSecondHalfOfTheKey() throws {
    let data = [UInt8](repeating: 0x11, count: 16)
    let ssc = bytes("0000000000000001")
    let k1 = bytes("0123456789abcdef")
    let a = try ApduEncrypter.desMac8.mac(data: data, sendSequenceCounter: ssc, macKey: k1 + k1)
    let b = try ApduEncrypter.desMac8.mac(
      data: data, sendSequenceCounter: ssc, macKey: k1 + bytes("fedcba9876543210"))
    XCTAssertNotEqual(a, b)
  }

  func testMacRejectsMisalignedOrShortInput() {
    let key = [UInt8](repeating: 0, count: 16)
    let ssc = [UInt8](repeating: 0, count: 8)
    XCTAssertThrowsError(
      try ApduEncrypter.des.mac(data: [0x01], sendSequenceCounter: ssc, macKey: key))
    XCTAssertThrowsError(
      try ApduEncrypter.des.mac(data: [], sendSequenceCounter: ssc, macKey: key))
    XCTAssertThrowsError(
      try ApduEncrypter.des.mac(
        data: [UInt8](repeating: 0, count: 8), sendSequenceCounter: ssc, macKey: [0x00]))
  }

  // MARK: - Data objects

  /// `87 L 01 ‖ cryptogram`, with the cryptogram verified against openssl.
  func testEncryptedDataObjectLayout() throws {
    let key = bytes("00112233445566778899aabbccddeeff")
    let object = try ApduEncrypter.des.encryptedDataObject([0x3F, 0x00], key: key)

    XCTAssertEqual(object[0], 0x87, "data object tag")
    XCTAssertEqual(object[1], 0x09, "length: indicator plus one cipher block")
    XCTAssertEqual(object[2], 0x01, "padding-content indicator")
    XCTAssertEqual(hex(Array(object.dropFirst(3))), "d6499e44673175ab")
  }

  func testNoDataYieldsNoDataObject() throws {
    let key = [UInt8](repeating: 0, count: 16)
    XCTAssertEqual(try ApduEncrypter.des.encryptedDataObject(nil, key: key), [])
    XCTAssertEqual(try ApduEncrypter.des.encryptedDataObject([], key: key), [])
  }

  func testExpectedLengthObjectLayout() {
    XCTAssertEqual(ApduEncrypter.des.expectedLengthObject(0xFF), [0x97, 0x01, 0xFF])
    XCTAssertEqual(ApduEncrypter.des.expectedLengthObject(0), [0x97, 0x01, 0x00])
    XCTAssertEqual(ApduEncrypter.des.expectedLengthObject(nil), [])
  }

  /// The Java narrows `Le` with `charValue()`, so 256 becomes 0. Preserved
  /// deliberately rather than "fixed" to a two-byte encoding.
  func testExtendedLengthIsTruncatedAsInTheJava() {
    XCTAssertEqual(ApduEncrypter.des.expectedLengthObject(256), [0x97, 0x01, 0x00])
  }

  // MARK: - Protecting a command

  func testProtectSetsTheSecureMessagingClassBit() throws {
    let apdu = CommandApdu(cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0x00, data: [0x3F, 0x00], le: 0)
    let protected = try ApduEncrypter.des.protect(
      apdu,
      encryptionKey: [UInt8](repeating: 0x11, count: 16),
      macKey: [UInt8](repeating: 0x22, count: 16),
      sendSequenceCounter: SendSequenceCounter(bytes: [0, 0, 0, 0, 0, 0, 0, 1])!
    )
    XCTAssertEqual(protected.cla, 0x0C)
    // The header fields are carried through untouched.
    XCTAssertEqual([protected.ins, protected.p1, protected.p2], [0xA4, 0x04, 0x00])
  }

  /// A CLA that already carries other bits keeps them; 0x0C is OR'd in.
  func testProtectPreservesOtherClassBits() throws {
    let apdu = CommandApdu(cla: 0x80, ins: 0x00, p1: 0x00, p2: 0x00)
    let protected = try ApduEncrypter.des.protect(
      apdu,
      encryptionKey: [UInt8](repeating: 0, count: 16),
      macKey: [UInt8](repeating: 0, count: 16),
      sendSequenceCounter: SendSequenceCounter(bytes: [UInt8](repeating: 0, count: 8))!
    )
    XCTAssertEqual(protected.cla, 0x8C)
  }

  func testProtectedCommandCarriesDataObjectsThenChecksum() throws {
    let apdu = CommandApdu(cla: 0x00, ins: 0xB0, p1: 0x00, p2: 0x00, data: [0xAA], le: 0x10)
    let protected = try ApduEncrypter.des.protect(
      apdu,
      encryptionKey: [UInt8](repeating: 0x11, count: 16),
      macKey: [UInt8](repeating: 0x22, count: 16),
      sendSequenceCounter: SendSequenceCounter(bytes: [0, 0, 0, 0, 0, 0, 0, 3])!
    )
    let body = try protected.command().data!

    XCTAssertEqual(body[0], 0x87, "cryptogram first")
    let leIndex = body.count - 3 - protected.mac.count - 2
    XCTAssertEqual(Array(body[leIndex..<(leIndex + 3)]), [0x97, 0x01, 0x10], "then Le")
    XCTAssertEqual(Array(body.suffix(6)), [0x8E, 0x04] + protected.mac, "then the MAC")
    XCTAssertEqual(protected.mac.count, 4)
  }

  /// Changing the counter must change the wire bytes even for an identical
  /// command — otherwise a captured APDU could simply be replayed.
  func testIdenticalCommandsDifferAcrossCounters() throws {
    let apdu = CommandApdu(cla: 0x00, ins: 0xB0, p1: 0x00, p2: 0x00, data: [0xAA], le: 0x10)
    let key = [UInt8](repeating: 0x11, count: 16)
    let mac = [UInt8](repeating: 0x22, count: 16)

    let first = try ApduEncrypter.des.protect(
      apdu, encryptionKey: key, macKey: mac,
      sendSequenceCounter: SendSequenceCounter(bytes: [0, 0, 0, 0, 0, 0, 0, 1])!)
    let second = try ApduEncrypter.des.protect(
      apdu, encryptionKey: key, macKey: mac,
      sendSequenceCounter: SendSequenceCounter(bytes: [0, 0, 0, 0, 0, 0, 0, 2])!)

    XCTAssertEqual(first.dataObjects, second.dataObjects, "the cryptogram itself is unchanged")
    XCTAssertNotEqual(first.mac, second.mac, "but the MAC is not")
  }

  // MARK: - Unwrapping a response

  /// Builds a response the way a card would, then unwraps it. This is a round
  /// trip through this code's own primitives, so it proves the two directions
  /// agree — not that a card would produce these bytes.
  private func cardResponse(
    plain: [UInt8]?, statusWord: [UInt8], encryptionKey: [UInt8], macKey: [UInt8],
    ssc: SendSequenceCounter, encrypter: ApduEncrypter
  ) throws -> ResponseApdu {
    var objects: [UInt8] = []
    if let plain {
      let cryptogram = try TripleDes.encrypt(
        Iso7816Padding.add(plain, blockSize: 8), key: encryptionKey)
      objects += BerTlv(tag: [0x87], value: [0x01] + cryptogram).encoded
    }
    objects += BerTlv(tag: [0x99], value: statusWord).encoded
    let mac = try encrypter.mac(
      data: Iso7816Padding.add(objects, blockSize: 8),
      sendSequenceCounter: ssc.bytes, macKey: macKey)
    let body = try SecureMessaging.appendingChecksum(to: objects, mac: mac)
    return ResponseApdu(bytes: body + [0x90, 0x00])
  }

  func testResponseRoundTrip() throws {
    let encryptionKey = [UInt8](repeating: 0x33, count: 16)
    let macKey = [UInt8](repeating: 0x44, count: 16)
    let ssc = SendSequenceCounter(bytes: [0, 0, 0, 0, 0, 0, 0, 9])!
    let plain: [UInt8] = [0x6F, 0x03, 0x84, 0x01, 0xAA]

    let wrapped = try cardResponse(
      plain: plain, statusWord: [0x90, 0x00], encryptionKey: encryptionKey,
      macKey: macKey, ssc: ssc, encrypter: .des)

    let decrypted = try ApduEncrypter.des.decrypt(
      response: wrapped, encryptionKey: encryptionKey, macKey: macKey,
      sendSequenceCounter: ssc)

    XCTAssertEqual(decrypted.data, plain)
    XCTAssertEqual(decrypted.statusWord, StatusWord(sw1: 0x90, sw2: 0x00))
  }

  /// A response can carry a status word and no data.
  func testResponseWithoutDataObject() throws {
    let encryptionKey = [UInt8](repeating: 0x33, count: 16)
    let macKey = [UInt8](repeating: 0x44, count: 16)
    let ssc = SendSequenceCounter(bytes: [0, 0, 0, 0, 0, 0, 0, 2])!

    let wrapped = try cardResponse(
      plain: nil, statusWord: [0x69, 0x82], encryptionKey: encryptionKey,
      macKey: macKey, ssc: ssc, encrypter: .des)
    let decrypted = try ApduEncrypter.des.decrypt(
      response: wrapped, encryptionKey: encryptionKey, macKey: macKey,
      sendSequenceCounter: ssc)

    XCTAssertEqual(decrypted.data, [])
    XCTAssertEqual(decrypted.statusWord, StatusWord(sw1: 0x69, sw2: 0x82))
  }

  /// Flipping one bit of the cryptogram must be caught by the MAC, not
  /// surface as garbled plaintext.
  func testTamperedCryptogramIsRejected() throws {
    let encryptionKey = [UInt8](repeating: 0x33, count: 16)
    let macKey = [UInt8](repeating: 0x44, count: 16)
    let ssc = SendSequenceCounter(bytes: [0, 0, 0, 0, 0, 0, 0, 9])!

    let wrapped = try cardResponse(
      plain: [0x01, 0x02, 0x03], statusWord: [0x90, 0x00],
      encryptionKey: encryptionKey, macKey: macKey, ssc: ssc, encrypter: .des)

    var tampered = wrapped.bytes
    tampered[4] ^= 0x01

    XCTAssertThrowsError(
      try ApduEncrypter.des.decrypt(
        response: ResponseApdu(bytes: tampered), encryptionKey: encryptionKey,
        macKey: macKey, sendSequenceCounter: ssc)
    ) { XCTAssertEqual($0 as? SecureChannelError, .invalidCryptographicChecksum) }
  }

  /// A response unwrapped at the wrong counter must fail. This is the test
  /// that would catch the counter drifting out of step with the card.
  func testWrongCounterFailsVerification() throws {
    let encryptionKey = [UInt8](repeating: 0x33, count: 16)
    let macKey = [UInt8](repeating: 0x44, count: 16)
    let ssc = SendSequenceCounter(bytes: [0, 0, 0, 0, 0, 0, 0, 9])!

    let wrapped = try cardResponse(
      plain: [0x01], statusWord: [0x90, 0x00], encryptionKey: encryptionKey,
      macKey: macKey, ssc: ssc, encrypter: .des)

    XCTAssertThrowsError(
      try ApduEncrypter.des.decrypt(
        response: wrapped, encryptionKey: encryptionKey, macKey: macKey,
        sendSequenceCounter: ssc.incremented())
    ) { XCTAssertEqual($0 as? SecureChannelError, .invalidCryptographicChecksum) }
  }

  func testResponseMissingRequiredObjectsIsRejected() {
    let key = [UInt8](repeating: 0, count: 16)
    let ssc = SendSequenceCounter(bytes: [UInt8](repeating: 0, count: 8))!

    // A status word object but no MAC.
    let noMac = ResponseApdu(bytes: [0x99, 0x02, 0x90, 0x00, 0x90, 0x00])
    XCTAssertThrowsError(
      try ApduEncrypter.des.decrypt(
        response: noMac, encryptionKey: key, macKey: key, sendSequenceCounter: ssc)
    ) { XCTAssertEqual($0 as? SecureChannelError, .missingResponseObject(tag: 0x8E)) }

    // A MAC but no status word.
    let noStatus = ResponseApdu(bytes: [0x8E, 0x04, 0, 0, 0, 0, 0x90, 0x00])
    XCTAssertThrowsError(
      try ApduEncrypter.des.decrypt(
        response: noStatus, encryptionKey: key, macKey: key, sendSequenceCounter: ssc)
    ) { XCTAssertEqual($0 as? SecureChannelError, .missingResponseObject(tag: 0x99)) }
  }

  /// A failed response is not wrapped, so it passes through untouched rather
  /// than failing MAC verification.
  func testUnsuccessfulResponsePassesThrough() throws {
    let key = [UInt8](repeating: 0, count: 16)
    let ssc = SendSequenceCounter(bytes: [UInt8](repeating: 0, count: 8))!
    let failure = ResponseApdu(bytes: [0x69, 0x82])

    let out = try ApduEncrypter.des.decrypt(
      response: failure, encryptionKey: key, macKey: key, sendSequenceCounter: ssc)
    XCTAssertEqual(out.bytes, failure.bytes)
  }
}
