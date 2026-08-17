import XCTest
@testable import DnieProtocol

/// Instruction bytes transcribed from the iso7816four command classes. The
/// Java constants are signed, so these assertions also document the mapping
/// from the negative values that appear in the transpiled source.
final class Iso7816CommandsTests: XCTestCase {

  func testInstructionBytesMatchTheSignedJavaConstants() {
    XCTAssertEqual(Iso7816.Ins.getChallenge, UInt8(bitPattern: -124))  // 0x84
    XCTAssertEqual(Iso7816.Ins.getResponse, UInt8(bitPattern: -64))    // 0xC0
    XCTAssertEqual(Iso7816.Ins.selectFile, UInt8(bitPattern: -92))     // 0xA4
  }

  func testGetChallengeDefaultsToEightBytes() {
    XCTAssertEqual(Iso7816.defaultChallengeLength, 8)
    XCTAssertEqual(Iso7816.getChallenge(cla: 0x00).bytes,
                   [0x00, 0x84, 0x00, 0x00, 0x08])
  }

  func testGetChallengeWithExplicitLength() {
    XCTAssertEqual(Iso7816.getChallenge(cla: 0x90, length: 4).bytes,
                   [0x90, 0x84, 0x00, 0x00, 0x04])
  }

  func testGetResponse() {
    XCTAssertEqual(Iso7816.getResponse(cla: 0x00, length: 0x1A).bytes,
                   [0x00, 0xC0, 0x00, 0x00, 0x1A])
  }

  /// SELECT FILE sends P1=SELECT_BY_ID(0x00), P2=SEARCH_FIRST(0x00) and no Le.
  func testSelectFileByIdSendsNoLe() {
    let apdu = Iso7816.selectFileById(cla: 0x00, fileId: [0x3F, 0x00])
    XCTAssertEqual(apdu.bytes, [0x00, 0xA4, 0x00, 0x00, 0x02, 0x3F, 0x00])
    XCTAssertNil(apdu.le)
  }
}
