import Security
import XCTest
@testable import DnieProtocol

/// The terminal credentials.
///
/// These are pure data, and data is where transcription errors hide: no test
/// of the surrounding logic can distinguish a correct modulus from one with a
/// flipped bit. So these tests check the data itself.
///
/// The strongest check is functional. `terminalModulus` and
/// `terminalPrivateExponent` are only a usable RSA key if
/// `m^d^e mod n == m` for every `m`; a single wrong bit in either breaks it.
/// That property is what recovered the public exponent in the first place —
/// it is not stored beside the key — and what proves the extraction is sound.
///
/// What none of this proves is that these are the credentials a *card* will
/// accept. They match the transpiled sources the working Android build runs,
/// which is the best evidence available without hardware.
final class Cwa14890ConstantsTests: XCTestCase {

  private var allSets: [(name: String, constants: Cwa14890Constants)] {
    [
      ("dnie", .dnie),
      ("dnie3Pin", .dnie3Pin),
      ("dnie3r2Pin", .dnie3r2Pin),
      ("dnie3r2Usr", .dnie3r2Usr),
    ]
  }

  // MARK: - The functional check

  /// Modular exponentiation, `base^exponent mod modulus`.
  ///
  /// Rather than hand-rolling 1024-bit arithmetic in a test, this borrows
  /// Apple's: a `SecKey` RSA *public* key is nothing but a (modulus, exponent)
  /// pair, and raw encryption with it is exactly modular exponentiation. So
  /// the private exponent is handed to `SecKeyCreateWithData` as though it
  /// were a public one. That is meaningless as cryptography and perfectly
  /// correct as arithmetic, which is all this test needs — and it keeps the
  /// check independent of the module's own RSA code.
  private func modPow(
    _ base: [UInt8], _ exponent: [UInt8], _ modulus: [UInt8]
  ) throws -> [UInt8] {
    func integer(_ bytes: [UInt8]) -> [UInt8] {
      // DER INTEGER: strip leading zeros, then re-add one if the high bit is
      // set, so the value stays positive.
      var value = Array(bytes.drop { $0 == 0 })
      if value.isEmpty { value = [0x00] }
      if value[0] & 0x80 != 0 { value.insert(0x00, at: 0) }
      return BerTlv(tag: [0x02], value: value).encoded
    }
    let der = BerTlv(tag: [0x30], value: integer(modulus) + integer(exponent)).encoded

    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
      kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
      kSecAttrKeySizeInBits as String: modulus.count * 8,
    ]
    var error: Unmanaged<CFError>?
    guard let key = SecKeyCreateWithData(
      Data(der) as CFData, attributes as CFDictionary, &error)
    else {
      throw XCTSkip("could not build a SecKey for modular exponentiation")
    }

    let block = Data(BigEndian.normalize(base, to: modulus.count))
    guard let out = SecKeyCreateEncryptedData(
      key, .rsaEncryptionRaw, block as CFData, &error) as Data?
    else {
      throw XCTSkip("raw RSA is unavailable on this host")
    }
    return [UInt8](out)
  }

  /// The check that makes this data testable at all.
  func testEveryKeyPairRoundTrips() throws {
    let probe: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF, 0x12, 0x34, 0x56, 0x78]

    for (name, constants) in allSets {
      let signed = try modPow(probe, constants.terminalPrivateExponent, constants.terminalModulus)
      let recovered = try modPow(signed, constants.terminalPublicExponent, constants.terminalModulus)

      // Strip the left-padding modPow returns at modulus width.
      let trimmed = Array(recovered.drop { $0 == 0 })
      XCTAssertEqual(
        trimmed, probe,
        "\(name): the key pair does not round-trip, so the extracted modulus or "
          + "private exponent is wrong")
    }
  }

  /// Signing must actually transform the input — a degenerate exponent would
  /// round-trip trivially.
  func testSigningIsNotTheIdentity() throws {
    let probe: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF, 0x12, 0x34, 0x56, 0x78]
    for (name, constants) in allSets {
      let signed = try modPow(probe, constants.terminalPrivateExponent, constants.terminalModulus)
      XCTAssertNotEqual(Array(signed.drop { $0 == 0 }), probe, "\(name)")
      XCTAssertEqual(signed.count, 128, "\(name): output is modulus-width")
    }
  }

  /// A deliberately corrupted modulus must fail the round trip. Without this,
  /// the test above could be passing for some reason other than correctness.
  func testACorruptedKeyFailsTheRoundTrip() throws {
    let probe: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF, 0x12, 0x34, 0x56, 0x78]
    var modulus = Cwa14890Constants.dnie.terminalModulus
    modulus[64] ^= 0x01  // one bit, in the middle

    let signed = try modPow(probe, Cwa14890Constants.dnie.terminalPrivateExponent, modulus)
    let recovered = try modPow(signed, Cwa14890Constants.dnie.terminalPublicExponent, modulus)
    XCTAssertNotEqual(Array(recovered.drop { $0 == 0 }), probe)
  }

  // MARK: - Shapes

  func testKeyMaterialHasTheExpectedWidths() {
    for (name, constants) in allSets {
      XCTAssertEqual(constants.terminalModulus.count, 128, "\(name): 1024-bit modulus")
      XCTAssertEqual(constants.terminalPrivateExponent.count, 128, "\(name)")
      XCTAssertEqual(constants.terminalPublicExponent, [0x01, 0x00, 0x01], "\(name): 65537")
    }
  }

  /// The terminal certificate is what the modulus must fit inside, and the
  /// handshake sends it verbatim.
  func testCertificatesHaveTheExpectedLengths() {
    for (name, constants) in allSets {
      XCTAssertEqual(constants.terminalCertificate.count, 209, "\(name): C_CV_IFD")
      XCTAssertEqual(constants.terminalCertificateReference.count, 8, "\(name): CHR_C_CV_IFD")
      XCTAssertEqual(constants.caCertificateReference.count, 8, "\(name): CHR_C_CV_CA")
      XCTAssertFalse(constants.caCertificate.isEmpty, "\(name): C_CV_CA")
      XCTAssertEqual(constants.caPublicKeyReference.count, 2, "\(name)")
      XCTAssertEqual(constants.cardPrivateKeyReference.count, 2, "\(name)")
    }
  }

  /// A CVC opens with the `7F 21` card-verifiable certificate tag.
  func testCertificatesAreCardVerifiableCertificates() {
    for (name, constants) in allSets {
      XCTAssertEqual(
        Array(constants.terminalCertificate.prefix(2)), [0x7F, 0x21],
        "\(name): terminal certificate should open with the CVC tag")
      XCTAssertEqual(
        Array(constants.caCertificate.prefix(2)), [0x7F, 0x21],
        "\(name): CA certificate should open with the CVC tag")
    }
  }

  /// The channels are distinct. If two of these ever collided, one channel
  /// would be authenticating with another's credentials.
  func testChannelsCarryDistinctCredentials() {
    let moduli = allSets.map(\.constants.terminalModulus)
    let references = allSets.map(\.constants.terminalCertificateReference)

    for i in moduli.indices {
      for j in moduli.indices where j > i {
        // dnie and the 3.0 user channel share a key by design; the sets listed
        // here are the four distinct ones, so all pairs must differ.
        XCTAssertNotEqual(
          moduli[i], moduli[j],
          "\(allSets[i].name) and \(allSets[j].name) share a modulus")
        XCTAssertNotEqual(
          references[i], references[j],
          "\(allSets[i].name) and \(allSets[j].name) share a certificate reference")
      }
    }
  }

  /// A private exponent must not be the public one — a paste error that would
  /// otherwise be invisible.
  func testPrivateExponentIsNotThePublicOne() {
    for (name, constants) in allSets {
      XCTAssertNotEqual(
        Array(constants.terminalPrivateExponent.drop { $0 == 0 }),
        constants.terminalPublicExponent, "\(name)")
    }
  }

  func testHexDecoderRoundTrips() {
    XCTAssertEqual(Cwa14890Constants.decode(""), [])
    XCTAssertEqual(Cwa14890Constants.decode("00ff10"), [0x00, 0xFF, 0x10])
  }
}
