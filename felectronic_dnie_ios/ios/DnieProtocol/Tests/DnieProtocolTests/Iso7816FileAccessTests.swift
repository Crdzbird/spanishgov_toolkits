import XCTest
@testable import DnieProtocol

/// File selection, whole-file reading, and the signing command.
///
/// The read loop is driven through a fake transport, so its chunking, its
/// end-of-file handling and its error paths are genuinely exercised rather
/// than merely compiled. What is still unproven is that a real DNIe answers
/// these APDUs the way the fake does.
final class Iso7816FileAccessTests: XCTestCase {

  /// A card that answers from a script, recording what it was asked.
  private final class FakeCard: ApduTransport {
    var sent: [CommandApdu] = []
    private var responses: [ResponseApdu]
    private var thrower: (() -> Error)?

    init(_ responses: [ResponseApdu], throwsOnCall: Int? = nil) {
      self.responses = responses
      if let throwsOnCall { self.throwAt = throwsOnCall }
    }
    var throwAt: Int?

    func transmit(_ command: CommandApdu) throws -> ResponseApdu {
      sent.append(command)
      if let throwAt, sent.count == throwAt {
        throw FileAccessError.unexpectedStatus(StatusWord(sw1: 0x6B, sw2: 0x00))
      }
      guard !responses.isEmpty else { return ResponseApdu(bytes: [0x90, 0x00]) }
      return responses.removeFirst()
    }
  }

  private func ok(_ data: [UInt8]) -> ResponseApdu { ResponseApdu(bytes: data + [0x90, 0x00]) }
  private func eof(_ data: [UInt8]) -> ResponseApdu { ResponseApdu(bytes: data + [0x62, 0x82]) }

  // MARK: - Command layouts

  func testReadBinarySplitsTheOffsetAcrossP1AndP2() {
    XCTAssertEqual(
      Iso7816FileCommands.readBinary(offset: 0, length: 222).bytes,
      [0x00, 0xB0, 0x00, 0x00, 0xDE])
    // 0x0123 => P1 0x01, P2 0x23.
    XCTAssertEqual(
      Iso7816FileCommands.readBinary(offset: 0x0123, length: 16).bytes,
      [0x00, 0xB0, 0x01, 0x23, 0x10])
  }

  /// 222, not 255 — the margin leaves room for secure-messaging overhead.
  func testMaxReadChunkMatchesTheJava() {
    XCTAssertEqual(Iso7816FileCommands.maxReadChunk, 222)
  }

  func testSelectDfByNameLayout() {
    let aid: [UInt8] = [0x4D, 0x61, 0x73, 0x74, 0x65, 0x72]
    XCTAssertEqual(
      Iso7816FileCommands.selectDfByName(name: aid).bytes,
      [0x00, 0xA4, 0x04, 0x00, 0x06] + aid)
  }

  func testGetResponseLayout() {
    XCTAssertEqual(
      Iso7816FileCommands.getResponse(length: 0x1F).bytes,
      [0x00, 0xC0, 0x00, 0x00, 0x1F])
  }

  /// P1 0x9E / P2 0x9A — the pair that says "return a signature over this
  /// hash". Getting either wrong makes the card refuse or sign the wrong
  /// thing.
  func testSignHashLayout() {
    let digestInfo: [UInt8] = [0x30, 0x21, 0x30, 0x09, 0x06, 0x05]
    let apdu = Iso7816FileCommands.signHash(digestInfo: digestInfo)
    XCTAssertEqual(Array(apdu.bytes.prefix(5)), [0x00, 0x2A, 0x9E, 0x9A, 0x06])
    XCTAssertEqual(apdu.data, digestInfo)
    XCTAssertNil(apdu.le)
  }

  // MARK: - File control information

  /// `6F L 81 02 <length>` — the descriptor the file length comes from.
  func testFciYieldsFileLength() throws {
    let fci = try FileControlInformation.decode([0x6F, 0x04, 0x81, 0x02, 0x03, 0x20])
    XCTAssertEqual(fci.fileLength, 0x0320)
  }

  func testFciWithFileIdentifierDescriptor() throws {
    // 6F 08 81 02 01 00 85 02 60 04
    let fci = try FileControlInformation.decode(
      [0x6F, 0x08, 0x81, 0x02, 0x01, 0x00, 0x85, 0x02, 0x60, 0x04])
    XCTAssertEqual(fci.fileLength, 256)
    XCTAssertEqual(fci.fileId, [0x60, 0x04])
  }

  func testFciRejectsNonTemplate() {
    XCTAssertThrowsError(try FileControlInformation.decode([0x62, 0x02, 0x81, 0x00]))
    XCTAssertThrowsError(try FileControlInformation.decode([0x6F]))
  }

  /// The Java only decodes when the declared length matches exactly.
  func testFciRejectsLengthMismatch() {
    XCTAssertThrowsError(
      try FileControlInformation.decode([0x6F, 0x08, 0x81, 0x02, 0x01, 0x00]))
  }

  func testFciWithoutLengthDescriptorYieldsZero() throws {
    let fci = try FileControlInformation.decode([0x6F, 0x04, 0x85, 0x02, 0x60, 0x04])
    XCTAssertEqual(fci.fileLength, 0)
    XCTAssertEqual(fci.fileId, [0x60, 0x04])
  }

  // MARK: - Reading

  func testShortFileIsReadInOneCommand() throws {
    let content = (0..<100).map { UInt8($0) }
    let card = FakeCard([ok(content)])
    let reader = Iso7816FileReader(transport: card)

    XCTAssertEqual(try reader.readBinary(length: 100), content)
    XCTAssertEqual(card.sent.count, 1)
    XCTAssertEqual(card.sent[0].le, 100, "asks for exactly what remains")
  }

  /// A file longer than one chunk is read in successive 222-byte requests,
  /// with the offset advancing across P1/P2.
  func testLongFileIsChunked() throws {
    let first = [UInt8](repeating: 0xA1, count: 222)
    let second = [UInt8](repeating: 0xB2, count: 222)
    let third = [UInt8](repeating: 0xC3, count: 56)
    let card = FakeCard([ok(first), ok(second), ok(third)])
    let reader = Iso7816FileReader(transport: card)

    let out = try reader.readBinary(length: 500)
    XCTAssertEqual(out.count, 500)
    XCTAssertEqual(out, first + second + third)

    XCTAssertEqual(card.sent.count, 3)
    XCTAssertEqual(card.sent.map(\.le), [222, 222, 56])
    // Offsets 0, 222 (0x00DE), 444 (0x01BC).
    XCTAssertEqual(card.sent.map { [$0.p1, $0.p2] }, [[0, 0], [0x00, 0xDE], [0x01, 0xBC]])
  }

  /// `62 82` is not a failure: the data that came with it is kept, and the
  /// loop stops. This is how a file shorter than its declared length ends.
  func testEndOfFileKeepsTheDataAndStops() throws {
    let first = [UInt8](repeating: 0xA1, count: 222)
    let tail = [UInt8](repeating: 0xB2, count: 30)
    let card = FakeCard([ok(first), eof(tail)])
    let reader = Iso7816FileReader(transport: card)

    // The card declares 1000 bytes but runs out after 252.
    let out = try reader.readBinary(length: 1000)
    XCTAssertEqual(out, first + tail)
    XCTAssertEqual(card.sent.count, 2, "stops as soon as the card reports EOF")
  }

  /// An offset past the end returns what was gathered rather than throwing —
  /// the Java logs a warning and returns.
  func testOffsetOutsideFileReturnsWhatWasRead() throws {
    let first = [UInt8](repeating: 0xA1, count: 222)
    let card = FakeCard([ok(first), ResponseApdu(bytes: [0x6B, 0x00])])
    let reader = Iso7816FileReader(transport: card)

    XCTAssertEqual(try reader.readBinary(length: 1000), first)
  }

  /// A transport failure mid-read also yields what was gathered.
  func testTransportFailureReturnsWhatWasRead() throws {
    let first = [UInt8](repeating: 0xA1, count: 222)
    let card = FakeCard([ok(first)], throwsOnCall: 2)
    let reader = Iso7816FileReader(transport: card)

    XCTAssertEqual(try reader.readBinary(length: 1000), first)
  }

  /// Any other failure is surfaced rather than silently truncating the file —
  /// a security-relevant distinction, since a caller receiving a short file
  /// would otherwise parse it as complete.
  func testOtherFailuresThrow() {
    let card = FakeCard([ResponseApdu(bytes: [0x69, 0x82])])
    let reader = Iso7816FileReader(transport: card)

    XCTAssertThrowsError(try reader.readBinary(length: 100)) { error in
      XCTAssertEqual(
        error as? FileAccessError,
        .unexpectedStatus(StatusWord(sw1: 0x69, sw2: 0x82)))
    }
  }

  func testZeroLengthReadsNothing() throws {
    let card = FakeCard([])
    let reader = Iso7816FileReader(transport: card)
    XCTAssertEqual(try reader.readBinary(length: 0), [])
    XCTAssertEqual(card.sent.count, 0, "no command is sent at all")
  }

  // MARK: - Select

  func testSelectReportsFileNotFound() {
    let card = FakeCard([ResponseApdu(bytes: [0x6A, 0x82])])
    let reader = Iso7816FileReader(transport: card)

    XCTAssertThrowsError(try reader.select(fileId: [0x60, 0x04])) { error in
      XCTAssertEqual(error as? FileAccessError, .fileNotFound(id: [0x60, 0x04]))
    }
  }

  /// Reading a card file before the secure channel is open produces `69 82`.
  /// Naming it distinctly is what makes that diagnosable.
  func testSelectReportsUnsatisfiedSecurityState() {
    let card = FakeCard([ResponseApdu(bytes: [0x69, 0x82])])
    let reader = Iso7816FileReader(transport: card)

    XCTAssertThrowsError(try reader.select(fileId: [0x60, 0x04])) { error in
      XCTAssertEqual(error as? FileAccessError, .securityStateNotSatisfied)
    }
  }

  func testSelectAndReadUsesTheDeclaredLength() throws {
    let content = [UInt8](repeating: 0x5A, count: 40)
    let card = FakeCard([
      ok([0x6F, 0x04, 0x81, 0x02, 0x00, 0x28]),  // declares 40 bytes
      ok(content),
    ])
    let reader = Iso7816FileReader(transport: card)

    XCTAssertEqual(try reader.selectAndRead(fileId: [0x60, 0x04]), content)
    XCTAssertEqual(card.sent[0].data, [0x60, 0x04])
    XCTAssertEqual(card.sent[1].le, 40)
  }

  /// The whole point of this layer: what comes off the card feeds the PKCS#15
  /// decoder from Stage 2.
  func testAReadFileParsesAsACertificateDirectory() throws {
    // A minimal CDF: one certificate object.
    let certificateObject: [UInt8] = [
      0x30, 0x13,
      0x30, 0x06, 0x0C, 0x04, 0x43, 0x65, 0x72, 0x74,     // label "Cert"
      0x30, 0x03, 0x04, 0x01, 0x01,                       // iD 0x01
      0xA1, 0x04, 0x30, 0x02, 0x04, 0x00,                 // [1] value = Path
    ]
    let card = FakeCard([
      ok([0x6F, 0x04, 0x81, 0x02, 0x00, UInt8(certificateObject.count)]),
      ok(certificateObject),
    ])
    let reader = Iso7816FileReader(transport: card)

    let bytes = try reader.selectAndRead(fileId: [0x60, 0x04])
    let cdf = try Pkcs15Cdf.decode(bytes)
    XCTAssertEqual(cdf.count, 1)
    XCTAssertEqual(cdf.certificates[0].label, "Cert")
    XCTAssertEqual(cdf.certificates[0].identifier, [0x01])
  }
}
