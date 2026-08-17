import XCTest
@testable import DnieProtocol

/// Byte-layout tests for `CommandApdu`.
///
/// The expectations are derived from
/// `jmulticard-objc/es/gob/jmulticard/apdu/CommandApdu.m`, whose Android build
/// is known to work against real DNIe cards. Any change that breaks these is a
/// change in what gets sent to the card.
final class CommandApduTests: XCTestCase {

  func testHeaderOnly() {
    let apdu = CommandApdu(cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0x00)
    XCTAssertEqual(apdu.bytes, [0x00, 0xA4, 0x04, 0x00])
  }

  func testLeOnly() {
    let apdu = CommandApdu(cla: 0x00, ins: 0x84, p1: 0x00, p2: 0x00, le: 8)
    XCTAssertEqual(apdu.bytes, [0x00, 0x84, 0x00, 0x00, 0x08])
  }

  func testShortData() {
    let apdu = CommandApdu(
      cla: 0x00, ins: 0xA4, p1: 0x00, p2: 0x00, data: [0x3F, 0x00]
    )
    XCTAssertEqual(apdu.bytes, [0x00, 0xA4, 0x00, 0x00, 0x02, 0x3F, 0x00])
  }

  func testDataAndLe() {
    let apdu = CommandApdu(
      cla: 0x00, ins: 0x88, p1: 0x00, p2: 0x00, data: [0xAA, 0xBB], le: 0x80
    )
    XCTAssertEqual(apdu.bytes, [0x00, 0x88, 0x00, 0x00, 0x02, 0xAA, 0xBB, 0x80])
  }

  /// jmulticard writes the Lc byte before testing whether the body is empty,
  /// so empty-but-present data still emits `Lc = 0x00`. This differs from
  /// passing `nil`, and the distinction is preserved.
  func testEmptyDataStillEmitsLengthByte() {
    let empty = CommandApdu(cla: 0x00, ins: 0x20, p1: 0x00, p2: 0x00, data: [])
    XCTAssertEqual(empty.bytes, [0x00, 0x20, 0x00, 0x00, 0x00])

    let none = CommandApdu(cla: 0x00, ins: 0x20, p1: 0x00, p2: 0x00, data: nil)
    XCTAssertEqual(none.bytes, [0x00, 0x20, 0x00, 0x00])

    XCTAssertNotEqual(empty.bytes, none.bytes)
  }

  func testBoundaryAt255BytesUsesShortForm() {
    let data = [UInt8](repeating: 0x41, count: 255)
    let apdu = CommandApdu(cla: 0x00, ins: 0x2A, p1: 0x00, p2: 0x00, data: data)
    XCTAssertEqual(Array(apdu.bytes.prefix(5)), [0x00, 0x2A, 0x00, 0x00, 0xFF])
    XCTAssertEqual(apdu.bytes.count, 4 + 1 + 255)
  }

  func testExtendedLcUsesThreeBytes() {
    let data = [UInt8](repeating: 0x42, count: 256)
    let apdu = CommandApdu(cla: 0x00, ins: 0x2A, p1: 0x00, p2: 0x00, data: data)
    // 00 then the 16-bit length, per jmulticard.
    XCTAssertEqual(Array(apdu.bytes.prefix(7)), [0x00, 0x2A, 0x00, 0x00, 0x00, 0x01, 0x00])
    XCTAssertEqual(apdu.bytes.count, 4 + 3 + 256)
  }

  /// jmulticard writes extended Le as two bytes, without the 0x00 prefix ISO
  /// 7816-4 requires when no extended Lc precedes it. Preserved deliberately;
  /// see the note on `CommandApdu`.
  func testExtendedLeUsesTwoBytesMatchingJmulticard() {
    let apdu = CommandApdu(cla: 0x00, ins: 0xB0, p1: 0x00, p2: 0x00, le: 0x0100)
    XCTAssertEqual(apdu.bytes, [0x00, 0xB0, 0x00, 0x00, 0x01, 0x00])
  }

  func testLeAt255StillSingleByte() {
    let apdu = CommandApdu(cla: 0x00, ins: 0xB0, p1: 0x00, p2: 0x00, le: 0xFF)
    XCTAssertEqual(apdu.bytes, [0x00, 0xB0, 0x00, 0x00, 0xFF])
  }
}
