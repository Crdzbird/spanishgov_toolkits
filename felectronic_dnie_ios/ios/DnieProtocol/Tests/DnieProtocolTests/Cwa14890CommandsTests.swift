import XCTest
@testable import DnieProtocol

/// Byte layouts for the handshake APDUs.
///
/// Every expectation is transcribed from the transpiled Java. What these tests
/// cannot check is the *order* the commands are sent in, or whether a real
/// card accepts them — see the note on ``Cwa14890Commands``.
final class Cwa14890CommandsTests: XCTestCase {

  // MARK: - MSE SET

  /// `83 0C <padded id> 84 LL <private key ref>`.
  func testAuthenticationKeyTemplateLayout() throws {
    let apdu = try Cwa14890Commands.setAuthenticationKey(
      publicKeyFileId: [0x02, 0x1F], privateKeyReference: [0x02])

    XCTAssertEqual(Array(apdu.bytes.prefix(4)), [0x00, 0x22, 0xC1, 0xA4])

    let data = apdu.data!
    XCTAssertEqual(data[0], 0x83, "public key reference tag")
    XCTAssertEqual(data[1], 0x0C, "always twelve bytes")
    // The identifier is right-aligned in its twelve bytes.
    XCTAssertEqual(Array(data[2..<14]), [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x02, 0x1F])
    XCTAssertEqual(Array(data[14...]), [0x84, 0x01, 0x02])
    XCTAssertEqual(data.count, 12 + 1 + 4)
  }

  func testFullWidthIdentifierIsNotPadded() throws {
    let id = (0..<12).map { UInt8($0 + 1) }
    let apdu = try Cwa14890Commands.setAuthenticationKey(
      publicKeyFileId: id, privateKeyReference: [0x03])
    XCTAssertEqual(Array(apdu.data![2..<14]), id)
  }

  /// The Java would throw from `arraycopy` here; this rejects it with a
  /// message that says what went wrong.
  func testOverlongIdentifierIsRejected() {
    XCTAssertThrowsError(
      try Cwa14890Commands.setAuthenticationKey(
        publicKeyFileId: [UInt8](repeating: 0xAA, count: 13),
        privateKeyReference: [0x02])
    )
  }

  func testMultiByteePrivateKeyReference() throws {
    let apdu = try Cwa14890Commands.setAuthenticationKey(
      publicKeyFileId: [0x01], privateKeyReference: [0x02, 0x03, 0x04])
    XCTAssertEqual(Array(apdu.data!.suffix(5)), [0x84, 0x03, 0x02, 0x03, 0x04])
  }

  /// A computation uses P1 0x41 and the digital signature template, not the
  /// authentication template — the pair that differs from every other MSE SET
  /// here.
  func testComputationUsesTheSignatureTemplate() {
    let apdu = Cwa14890Commands.setComputation(data: [0x80, 0x01, 0x02])
    XCTAssertEqual(Array(apdu.bytes.prefix(4)), [0x00, 0x22, 0x41, 0xB6])
  }

  func testAuthenticationTemplateUsesItsOwnPair() {
    let apdu = Cwa14890Commands.setAuthenticationTemplate(data: [0x83, 0x01, 0x02])
    XCTAssertEqual(Array(apdu.bytes.prefix(4)), [0x00, 0x22, 0xC1, 0xA4])
  }

  // MARK: - The handshake

  /// The data field is the random and the key reference concatenated, with no
  /// tags between them.
  func testInternalAuthenticateConcatenatesWithoutTags() {
    let randomIfd = [UInt8](repeating: 0xAA, count: 8)
    let apdu = Cwa14890Commands.internalAuthenticate(
      randomIfd: randomIfd, privateKeyReference: [0x02, 0x1F])

    XCTAssertEqual(apdu.bytes, [0x00, 0x88, 0x00, 0x00, 0x0A] + randomIfd + [0x02, 0x1F])
    XCTAssertNil(apdu.le, "no Le is sent")
  }

  func testExternalAuthenticateCarriesTheTokenVerbatim() {
    let token = (0..<128).map { UInt8($0) }
    let apdu = Cwa14890Commands.externalAuthenticate(authenticationToken: token)

    XCTAssertEqual(Array(apdu.bytes.prefix(5)), [0x00, 0x82, 0x00, 0x00, 0x80])
    XCTAssertEqual(apdu.data, token)
    XCTAssertNil(apdu.le)
  }

  func testVerifyCertificateLayout() {
    let certificate = [UInt8](repeating: 0x7F, count: 200)
    let apdu = Cwa14890Commands.verifyCertificate(certificate: certificate)

    // 200 bytes still fits the short form.
    XCTAssertEqual(Array(apdu.bytes.prefix(5)), [0x00, 0x2A, 0x00, 0xAE, 0xC8])
    XCTAssertEqual(apdu.data, certificate)
  }

  /// The secure channel is not open during the handshake, so these go out with
  /// a plain class byte. Any caller passing 0x0C here would be wrapping a
  /// command the card cannot yet decrypt.
  func testHandshakeCommandsDefaultToAPlainClassByte() throws {
    XCTAssertEqual(Cwa14890Commands.internalAuthenticate(
      randomIfd: [], privateKeyReference: []).cla, 0x00)
    XCTAssertEqual(Cwa14890Commands.externalAuthenticate(
      authenticationToken: []).cla, 0x00)
    XCTAssertEqual(Cwa14890Commands.verifyCertificate(certificate: []).cla, 0x00)
    XCTAssertEqual(try Cwa14890Commands.setAuthenticationKey(
      publicKeyFileId: [], privateKeyReference: []).cla, 0x00)
  }

  /// Constants, pinned against the transpiled values so a typo shows up here
  /// rather than as an unexplained card rejection.
  func testInstructionBytesMatchTheJava() {
    XCTAssertEqual(Cwa14890Commands.insManageSecurityEnvironment, 0x22)
    XCTAssertEqual(Cwa14890Commands.insInternalAuthenticate, 0x88)
    XCTAssertEqual(Cwa14890Commands.insExternalAuthenticate, 0x82)
    XCTAssertEqual(Cwa14890Commands.insPerformSecurityOperation, 0x2A)
    XCTAssertEqual(Cwa14890Commands.setForAuthentication, 0xC1)
    XCTAssertEqual(Cwa14890Commands.setForComputation, 0x41)
    XCTAssertEqual(Cwa14890Commands.authenticationTemplate, 0xA4)
    XCTAssertEqual(Cwa14890Commands.digitalSignatureTemplate, 0xB6)
    XCTAssertEqual(Cwa14890Commands.publicKeyReferenceTag, 0x83)
    XCTAssertEqual(Cwa14890Commands.privateKeyReferenceTag, 0x84)
    XCTAssertEqual(Cwa14890Commands.algorithmReferenceTag, 0x80)
  }
}
