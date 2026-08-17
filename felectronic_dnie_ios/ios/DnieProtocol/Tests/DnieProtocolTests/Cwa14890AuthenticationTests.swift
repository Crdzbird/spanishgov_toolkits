import Security
import XCTest
@testable import DnieProtocol

/// The CWA-14890 mutual authentication exchange.
///
/// These tests generate real RSA key pairs and run both halves of the exchange
/// through them, including the card side, which this module does not implement
/// and which is simulated here.
///
/// **What that proves:** recovery inverts construction, the `min(sig, n - sig)`
/// reflection is handled in both branches, and the digest binds what it is
/// supposed to bind.
///
/// **What it does not prove:** that a DNIe agrees with any of it. The card side
/// simulated below is my reading of the Java, so a misreading would be mirrored
/// on both sides and every test would still pass. This is the part of the
/// channel with no external reference — no published vector, no second
/// implementation to check against. It is exactly as trustworthy as the
/// transcription, and no more.
final class Cwa14890AuthenticationTests: XCTestCase {

  // MARK: - Key material

  /// A 1024-bit pair, matching the DNIe's key size.
  private func makeKeyPair() throws -> (cipher: SecKeyRsaCipher, secKey: SecKey) {
    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrKeySizeInBits as String: 1024,
    ]
    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
          let publicKey = SecKeyCopyPublicKey(privateKey)
    else {
      throw XCTSkip("could not generate an RSA key pair on this host")
    }
    return (try SecKeyRsaCipher(publicKey: publicKey, privateKey: privateKey), privateKey)
  }

  /// A terminal/card pair on which wrapping under one key and unwrapping under
  /// the other round-trips faithfully.
  ///
  /// Raw RSA reduces modulo the modulus, so a value produced under the card's
  /// key is only recoverable if it is below the terminal's modulus too. The
  /// protocol guarantees this by transmitting `min(sig, n - sig)`; with
  /// randomly generated keys it can still fail, and a test that tripped over
  /// it would look like a protocol bug rather than a fixture problem. This
  /// rejects such pairs explicitly instead of leaving the suite flaky.
  private func makeCompatiblePair() throws -> (
    terminal: SecKeyRsaCipher, terminalPublic: SecKeyRsaCipher,
    card: SecKeyRsaCipher, cardPublic: SecKeyRsaCipher
  ) {
    for _ in 0..<12 {
      let (terminal, terminalSecKey) = try makeKeyPair()
      let (card, cardSecKey) = try makeKeyPair()
      // Half the modulus is the largest value the reduction can yield.
      var half = card.modulus
      var carry: UInt8 = 0
      for i in half.indices {
        let value = half[i]
        half[i] = (value >> 1) | (carry << 7)
        carry = value & 1
      }
      guard BigEndian.compare(half, terminal.modulus) == .orderedAscending else { continue }
      return (
        terminal, try publicOnly(terminal, from: terminalSecKey),
        card, try publicOnly(card, from: cardSecKey)
      )
    }
    throw XCTSkip("could not generate a compatible key pair in twelve attempts")
  }

  /// The public half only — how the card's key is seen by the terminal.
  private func publicOnly(_ cipher: SecKeyRsaCipher, from key: SecKey) throws -> SecKeyRsaCipher {
    try SecKeyRsaCipher(publicKey: SecKeyCopyPublicKey(key)!)
  }

  // MARK: - Big-endian arithmetic

  func testCompareIgnoresLeadingZeros() {
    XCTAssertEqual(BigEndian.compare([0x00, 0x01], [0x01]), .orderedSame)
    XCTAssertEqual(BigEndian.compare([0x02], [0x00, 0x01]), .orderedDescending)
    XCTAssertEqual(BigEndian.compare([0x00], [0x00, 0x00]), .orderedSame)
    XCTAssertEqual(BigEndian.compare([0x01, 0x00], [0xFF]), .orderedDescending)
  }

  func testSubtractBorrowsAcrossBytes() {
    XCTAssertEqual(BigEndian.subtract([0x01, 0x00], [0x01], width: 2), [0x00, 0xFF])
    XCTAssertEqual(BigEndian.subtract([0x01, 0x00, 0x00], [0x01], width: 3), [0x00, 0xFF, 0xFF])
    XCTAssertEqual(BigEndian.subtract([0x05], [0x05], width: 1), [0x00])
    XCTAssertEqual(BigEndian.subtract([0xFF, 0xFF], [0x00], width: 2), [0xFF, 0xFF])
  }

  func testNormalizeMatchesBigIntegerRoundTrip() {
    // A sign byte from BigInteger.toByteArray() is dropped.
    XCTAssertEqual(BigEndian.normalize([0x00, 0x80, 0x01], to: 2), [0x80, 0x01])
    // A short value is left-padded.
    XCTAssertEqual(BigEndian.normalize([0x01], to: 4), [0x00, 0x00, 0x00, 0x01])
    XCTAssertEqual(BigEndian.normalize([0xAA, 0xBB], to: 2), [0xAA, 0xBB])
  }

  // MARK: - Block layout

  func testWellFormedRequiresBothPaddingBytes() {
    let size = Cwa14890Authentication.fixedOverhead + 10
    var block = [UInt8](repeating: 0x11, count: size)
    block[0] = 0x6A
    block[size - 1] = 0xBC
    XCTAssertTrue(Cwa14890Authentication.isWellFormed(block))

    var noStart = block; noStart[0] = 0x00
    XCTAssertFalse(Cwa14890Authentication.isWellFormed(noStart))

    var noEnd = block; noEnd[size - 1] = 0x00
    XCTAssertFalse(Cwa14890Authentication.isWellFormed(noEnd))

    XCTAssertFalse(Cwa14890Authentication.isWellFormed([0x6A, 0xBC]), "too short to hold the fields")
  }

  /// `PRND` is whatever the modulus leaves after the fixed fields, so a
  /// 128-byte block carries 74 bytes of it.
  func testSplitSizesPrndFromWhatIsLeftOver() throws {
    let prnd = [UInt8](repeating: 0xA1, count: 74)
    let kicc = [UInt8](repeating: 0xB2, count: 32)
    let hash = [UInt8](repeating: 0xC3, count: 20)
    let block = [0x6A] + prnd + kicc + hash + [0xBC]
    XCTAssertEqual(block.count, 128)

    let parts = try Cwa14890Authentication.split(block)
    XCTAssertEqual(parts.prnd, prnd)
    XCTAssertEqual(parts.keyMaterial, kicc)
    XCTAssertEqual(parts.digest, hash)
  }

  // MARK: - Padded serial

  func testSerialIsLeftPaddedToEightBytes() {
    XCTAssertEqual(
      Cwa14890Authentication.paddedSerial([0xAA, 0xBB]),
      [0, 0, 0, 0, 0, 0, 0xAA, 0xBB]
    )
    let exact = [UInt8](repeating: 0x11, count: 8)
    XCTAssertEqual(Cwa14890Authentication.paddedSerial(exact), exact)
    // The Java does not truncate a longer serial, and neither does this.
    let long = [UInt8](repeating: 0x22, count: 10)
    XCTAssertEqual(Cwa14890Authentication.paddedSerial(long), long)
  }

  // MARK: - Session seed

  func testSessionSeedIsTheXorOfBothHalves() throws {
    let kicc = [UInt8](repeating: 0xF0, count: 32)
    let kifd = [UInt8](repeating: 0x0F, count: 32)
    XCTAssertEqual(
      try Cwa14890Authentication.sessionSeed(cardKeyMaterial: kicc, terminalKeyMaterial: kifd),
      [UInt8](repeating: 0xFF, count: 32)
    )
  }

  /// Neither side alone fixes the seed — the point of contributing halves.
  func testEitherHalfChangingChangesTheSeed() throws {
    let a = [UInt8](repeating: 0x01, count: 32)
    let b = [UInt8](repeating: 0x02, count: 32)
    var c = b; c[0] = 0x03

    let base = try Cwa14890Authentication.sessionSeed(cardKeyMaterial: a, terminalKeyMaterial: b)
    let moved = try Cwa14890Authentication.sessionSeed(cardKeyMaterial: a, terminalKeyMaterial: c)
    XCTAssertNotEqual(base, moved)
  }

  func testSeedRejectsWrongLengths() {
    XCTAssertThrowsError(
      try Cwa14890Authentication.sessionSeed(
        cardKeyMaterial: [0x01], terminalKeyMaterial: [UInt8](repeating: 0, count: 32))
    )
  }

  // MARK: - Internal authentication, end to end against real keys

  /// Simulates what the card does so the terminal's recovery can be exercised.
  ///
  /// The card signs `6A ‖ PRND ‖ Kicc ‖ H ‖ BC` with its private key, reduces
  /// to `min(sig, n - sig)`, then wraps under the terminal's public key.
  private func cardInternalAuthenticate(
    kicc: [UInt8], randomIfd: [UInt8], chrCCvIfd: [UInt8],
    cardKey: SecKeyRsaCipher, terminalPublic: SecKeyRsaCipher
  ) throws -> [UInt8] {
    let prnd = [UInt8](repeating: 0x5A, count: cardKey.modulusLength - 54)
    let hash = Cwa14890Authentication.digest(
      prnd: prnd, keyMaterial: kicc, challenge: randomIfd, identifier: chrCCvIfd)
    let block = [0x6A] + prnd + kicc + hash + [0xBC]

    let signature = try cardKey.privateOperation(block)
    // A real card always transmits min(sig, n - sig). Simulating anything else
    // produces a value that may exceed the terminal's modulus, which is the
    // very situation the reduction exists to prevent.
    let reflected = BigEndian.subtract(
      cardKey.modulus, BigEndian.stripLeadingZeros(signature),
      width: cardKey.modulusLength)
    let transmitted = BigEndian.compare(signature, reflected) == .orderedDescending
      ? reflected : signature
    return try terminalPublic.publicOperation(transmitted)
  }

  func testRecoversCardKeyMaterialEndToEnd() throws {
    let (terminal, terminalPublic, card, cardPublic) = try makeCompatiblePair()

    let kicc = [UInt8](repeating: 0x7E, count: 32)
    let randomIfd = [UInt8](repeating: 0x11, count: 8)
    let chrCCvIfd = [UInt8](repeating: 0x22, count: 12)

    let signature = try cardInternalAuthenticate(
      kicc: kicc, randomIfd: randomIfd, chrCCvIfd: chrCCvIfd,
      cardKey: card, terminalPublic: terminalPublic)

    XCTAssertEqual(
      try Cwa14890Authentication.recoverCardKeyMaterial(
        signature: signature, randomIfd: randomIfd,
        terminalCertificateReference: chrCCvIfd,
        terminalKey: terminal, cardKey: cardPublic),
      kicc
    )
  }

  /// The same exchange with the signature reduced to `n - sig`, which exercises
  /// the reflection branch. Whether the reduction actually fires depends on the
  /// keys, so this runs several pairs to make sure the branch is reached.
  func testRecoversThroughTheReflectionBranch() throws {
    // Each attempt has roughly a one-in-two chance of producing a signature
    // above n/2. Twenty-four attempts puts a spurious failure below one in a
    // million, which matters because the assertion at the end is deliberately
    // a hard failure rather than a silent skip: a run that never reaches the
    // branch has proved nothing, and should say so.
    var reflectionExercised = false

    for _ in 0..<24 {
      let (terminal, terminalSecKey) = try makeKeyPair()
      let (card, cardSecKey) = try makeKeyPair()
      let terminalPublic = try publicOnly(terminal, from: terminalSecKey)
      let cardPublic = try publicOnly(card, from: cardSecKey)

      let kicc = [UInt8](repeating: 0x3C, count: 32)
      let randomIfd = [UInt8](repeating: 0xAB, count: 8)
      let chrCCvIfd = [UInt8](repeating: 0xCD, count: 12)

      let prnd = [UInt8](repeating: 0x5A, count: card.modulusLength - 54)
      let hash = Cwa14890Authentication.digest(
        prnd: prnd, keyMaterial: kicc, challenge: randomIfd, identifier: chrCCvIfd)
      let block = [0x6A] + prnd + kicc + hash + [0xBC]
      let signature = try card.privateOperation(block)
      let reflected = BigEndian.subtract(
        card.modulus, BigEndian.stripLeadingZeros(signature), width: card.modulusLength)

      guard BigEndian.compare(signature, reflected) == .orderedDescending else { continue }
      reflectionExercised = true

      let transmitted = try terminalPublic.publicOperation(reflected)
      XCTAssertEqual(
        try Cwa14890Authentication.recoverCardKeyMaterial(
          signature: transmitted, randomIfd: randomIfd,
          terminalCertificateReference: chrCCvIfd,
          terminalKey: terminal, cardKey: cardPublic),
        kicc,
        "recovery must succeed when the card sent n - sig"
      )
      break
    }

    XCTAssertTrue(
      reflectionExercised,
      "no generated key pair produced a signature above n/2 in 24 attempts; "
        + "the reflection branch was never reached, so this test proved nothing"
    )
  }

  /// The digest binds the challenge. If it did not, a recorded exchange could
  /// be replayed against a fresh challenge.
  func testRecoveryFailsWhenTheChallengeDiffers() throws {
    let (terminal, terminalPublic, card, cardPublic) = try makeCompatiblePair()

    let signature = try cardInternalAuthenticate(
      kicc: [UInt8](repeating: 0x7E, count: 32),
      randomIfd: [UInt8](repeating: 0x11, count: 8),
      chrCCvIfd: [UInt8](repeating: 0x22, count: 12),
      cardKey: card, terminalPublic: terminalPublic)

    XCTAssertThrowsError(
      try Cwa14890Authentication.recoverCardKeyMaterial(
        signature: signature,
        randomIfd: [UInt8](repeating: 0x99, count: 8),  // a different challenge
        terminalCertificateReference: [UInt8](repeating: 0x22, count: 12),
        terminalKey: terminal, cardKey: cardPublic)
    )
  }

  /// The digest also binds the terminal's certificate reference, which is what
  /// stops the exchange being redirected to a different terminal.
  func testRecoveryFailsWhenTheCertificateReferenceDiffers() throws {
    let (terminal, terminalPublic, card, cardPublic) = try makeCompatiblePair()

    let signature = try cardInternalAuthenticate(
      kicc: [UInt8](repeating: 0x7E, count: 32),
      randomIfd: [UInt8](repeating: 0x11, count: 8),
      chrCCvIfd: [UInt8](repeating: 0x22, count: 12),
      cardKey: card, terminalPublic: terminalPublic)

    XCTAssertThrowsError(
      try Cwa14890Authentication.recoverCardKeyMaterial(
        signature: signature,
        randomIfd: [UInt8](repeating: 0x11, count: 8),
        terminalCertificateReference: [UInt8](repeating: 0x33, count: 12),  // different
        terminalKey: terminal, cardKey: cardPublic)
    )
  }

  // MARK: - External authentication

  /// Builds the terminal's payload, then unwraps it the way the card would and
  /// checks the recovered block matches what went in.
  func testExternalAuthenticationRoundTrip() throws {
    let (terminal, terminalPublic, card, cardPublic) = try makeCompatiblePair()

    let kifd = [UInt8](repeating: 0x4D, count: 32)
    let prnd = [UInt8](repeating: 0x6E, count: terminal.modulusLength - 54)
    let randomIcc = [UInt8](repeating: 0x77, count: 8)
    let serial = Cwa14890Authentication.paddedSerial([0x01, 0x02, 0x03])

    let result = try Cwa14890Authentication.buildExternalAuthentication(
      prnd: prnd, keyMaterial: kifd, randomIcc: randomIcc, paddedSerial: serial,
      terminalKey: terminal, cardKey: cardPublic)

    XCTAssertEqual(result.keyMaterial, kifd)

    // The card unwraps with its private key, then applies the terminal's
    // public exponent — trying the reflection if the first form is malformed.
    let sigMin = try card.privateOperation(result.message)
    var recovered = try terminalPublic.publicOperation(sigMin)
    if !Cwa14890Authentication.isWellFormed(recovered) {
      let reflected = BigEndian.subtract(
        terminal.modulus, BigEndian.stripLeadingZeros(sigMin),
        width: terminal.modulusLength)
      recovered = try terminalPublic.publicOperation(reflected)
    }

    XCTAssertTrue(
      Cwa14890Authentication.isWellFormed(recovered),
      "the card could not recover a well-formed block from the terminal's message")

    let parts = try Cwa14890Authentication.split(recovered)
    XCTAssertEqual(parts.keyMaterial, kifd)
    XCTAssertEqual(parts.prnd, prnd)
    XCTAssertEqual(
      parts.digest,
      Cwa14890Authentication.digest(
        prnd: prnd, keyMaterial: kifd, challenge: randomIcc, identifier: serial))
  }

  /// The transmitted signature must never exceed half the modulus — that is
  /// what the reduction is for.
  ///
  /// Whether the reduction actually fires is key-dependent: about half of all
  /// signatures are already the smaller form, and for those the reduction is a
  /// no-op that this test could not distinguish from its absence. So it keeps
  /// generating pairs until it finds one where the reduction is genuinely
  /// needed, and fails outright if it never does — otherwise a missing
  /// reduction would slip through roughly half the time.
  func testTransmittedSignatureIsTheSmallerForm() throws {
    // As above: 24 attempts so a spurious failure is negligible while the
    // assertion stays a hard failure.
    var reductionExercised = false

    for _ in 0..<24 {
      let (terminal, _, card, cardPublic) = try makeCompatiblePair()
      let prnd = [UInt8](repeating: 0x6E, count: terminal.modulusLength - 54)
      let kifd = [UInt8](repeating: 0x4D, count: 32)
      let randomIcc = [UInt8](repeating: 0x77, count: 8)
      let serial = [UInt8](repeating: 0x00, count: 8)

      // Determine, independently of the code under test, whether this key
      // makes the reduction necessary.
      let hash = Cwa14890Authentication.digest(
        prnd: prnd, keyMaterial: kifd, challenge: randomIcc, identifier: serial)
      let rawSignature = try terminal.privateOperation([0x6A] + prnd + kifd + hash + [0xBC])
      let rawReflected = BigEndian.subtract(
        terminal.modulus, BigEndian.stripLeadingZeros(rawSignature),
        width: terminal.modulusLength)
      guard BigEndian.compare(rawSignature, rawReflected) == .orderedDescending else { continue }
      reductionExercised = true

      let result = try Cwa14890Authentication.buildExternalAuthentication(
        prnd: prnd, keyMaterial: kifd, randomIcc: randomIcc, paddedSerial: serial,
        terminalKey: terminal, cardKey: cardPublic)

      let transmitted = try card.privateOperation(result.message)
      XCTAssertEqual(
        transmitted, rawReflected,
        "the reduction was required for this key, so n - sig must have been sent")

      let reflected = BigEndian.subtract(
        terminal.modulus, BigEndian.stripLeadingZeros(transmitted),
        width: terminal.modulusLength)
      XCTAssertNotEqual(
        BigEndian.compare(transmitted, reflected), .orderedDescending,
        "the transmitted value must be the smaller of sig and n - sig")
      break
    }

    XCTAssertTrue(
      reductionExercised,
      "no key pair in 24 attempts produced a signature above n/2, so the "
        + "reduction was never exercised and this test proved nothing")
  }

  func testWrongKeyMaterialLengthIsRejected() throws {
    let (terminal, _, _, cardPublic) = try makeCompatiblePair()

    XCTAssertThrowsError(
      try Cwa14890Authentication.buildExternalAuthentication(
        prnd: [UInt8](repeating: 0x00, count: 74),
        keyMaterial: [UInt8](repeating: 0x00, count: 16),  // must be 32
        randomIcc: [UInt8](repeating: 0x00, count: 8),
        paddedSerial: [UInt8](repeating: 0x00, count: 8),
        terminalKey: terminal, cardKey: cardPublic)
    )
  }

  /// `generate` must draw fresh material every call.
  func testGenerateProducesDistinctKeyMaterial() throws {
    let (terminal, _, _, cardPublic) = try makeCompatiblePair()
    let serial = [UInt8](repeating: 0x00, count: 8)
    let randomIcc = [UInt8](repeating: 0x00, count: 8)

    let first = try Cwa14890Authentication.generate(
      randomIcc: randomIcc, paddedSerial: serial, terminalKey: terminal, cardKey: cardPublic)
    let second = try Cwa14890Authentication.generate(
      randomIcc: randomIcc, paddedSerial: serial, terminalKey: terminal, cardKey: cardPublic)

    XCTAssertEqual(first.keyMaterial.count, 32)
    XCTAssertNotEqual(first.keyMaterial, second.keyMaterial)
    XCTAssertNotEqual(first.message, second.message)
  }

  // MARK: - The whole exchange feeding the session keys

  /// Both halves through to the derived session keys, which is what Stage 3a
  /// consumes. Ties the authentication exchange to the rest of the channel.
  func testExchangeProducesUsableSessionKeys() throws {
    let (terminal, terminalPublic, card, cardPublic) = try makeCompatiblePair()

    let randomIfd = [UInt8](repeating: 0x11, count: 8)
    let randomIcc = [UInt8](repeating: 0x22, count: 8)
    let chrCCvIfd = [UInt8](repeating: 0x33, count: 12)
    let kicc = [UInt8](repeating: 0x44, count: 32)

    let cardSignature = try cardInternalAuthenticate(
      kicc: kicc, randomIfd: randomIfd, chrCCvIfd: chrCCvIfd,
      cardKey: card, terminalPublic: terminalPublic)

    let recoveredKicc = try Cwa14890Authentication.recoverCardKeyMaterial(
      signature: cardSignature, randomIfd: randomIfd,
      terminalCertificateReference: chrCCvIfd,
      terminalKey: terminal, cardKey: cardPublic)

    let external = try Cwa14890Authentication.generate(
      randomIcc: randomIcc,
      paddedSerial: Cwa14890Authentication.paddedSerial([0xAA]),
      terminalKey: terminal, cardKey: cardPublic)

    let seed = try Cwa14890Authentication.sessionSeed(
      cardKeyMaterial: recoveredKicc, terminalKeyMaterial: external.keyMaterial)
    XCTAssertEqual(seed.count, 32)

    let kenc = Cwa14890KeyDerivation.encryptionKey(seed: seed)
    let kmac = Cwa14890KeyDerivation.macKey(seed: seed)
    XCTAssertEqual(kenc.count, 16)
    XCTAssertEqual(kmac.count, 16)
    XCTAssertNotEqual(kenc, kmac)

    // Those keys drive the encrypter, closing the loop with Stage 3b.
    let ssc = try SendSequenceCounter(randomIfd: randomIfd, randomIcc: randomIcc)
    let protected = try ApduEncrypter.des.protect(
      CommandApdu(cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0x00, data: [0x3F, 0x00], le: 0),
      encryptionKey: kenc, macKey: kmac, sendSequenceCounter: ssc)
    XCTAssertEqual(protected.cla, 0x0C)
    XCTAssertEqual(protected.mac.count, 4)
  }
}
