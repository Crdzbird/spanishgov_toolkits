import XCTest
@testable import DnieProtocol

/// Derived from `jmulticard-objc/es/gob/jmulticard/apdu/ResponseApdu.m` and
/// `StatusWord.m`.
final class ResponseApduTests: XCTestCase {

  func testSplitsPayloadFromStatusWord() {
    let r = ResponseApdu(bytes: [0x01, 0x02, 0x03, 0x90, 0x00])
    XCTAssertEqual(r.data, [0x01, 0x02, 0x03])
    XCTAssertEqual(r.statusWord, StatusWord(sw1: 0x90, sw2: 0x00))
    XCTAssertTrue(r.isOk)
  }

  func testStatusWordOnly() {
    let r = ResponseApdu(bytes: [0x90, 0x00])
    XCTAssertEqual(r.data, [])
    XCTAssertTrue(r.isOk)
  }

  /// jmulticard returns null (and logs) for responses shorter than two bytes.
  /// Here that is an Optional, and `data` yields empty rather than trapping —
  /// the Java would compute a negative array size.
  func testShortResponseHasNoStatusWord() {
    XCTAssertNil(ResponseApdu(bytes: [0x90]).statusWord)
    XCTAssertNil(ResponseApdu(bytes: []).statusWord)
    XCTAssertEqual(ResponseApdu(bytes: [0x90]).data, [])
    XCTAssertFalse(ResponseApdu(bytes: [0x90]).isOk)
  }

  /// isOk is strictly 90 00 — warnings and "more data" are not success.
  func testOnlyNineThousandIsOk() {
    XCTAssertFalse(ResponseApdu(bytes: [0x61, 0x1A]).isOk)
    XCTAssertFalse(ResponseApdu(bytes: [0x62, 0x83]).isOk)
    XCTAssertFalse(ResponseApdu(bytes: [0x6A, 0x82]).isOk)
    XCTAssertTrue(ResponseApdu(bytes: [0x90, 0x00]).isOk)
  }

  func testMoreDataAvailable() {
    let sw = ResponseApdu(bytes: [0x61, 0x1A]).statusWord
    XCTAssertEqual(sw?.hasMoreData, true)
    XCTAssertEqual(sw?.remainingBytes, 0x1A)
    // 61 00 means 256 bytes pending, not zero.
    XCTAssertEqual(StatusWord(sw1: 0x61, sw2: 0x00).remainingBytes, 256)
  }

  func testWrongLe() {
    XCTAssertEqual(StatusWord(sw1: 0x6C, sw2: 0x20).wrongLe, 0x20)
    XCTAssertNil(StatusWord(sw1: 0x90, sw2: 0x00).wrongLe)
  }

  func testEncryptedBytesArePreserved() {
    let r = ResponseApdu(bytes: [0x90, 0x00], encryptedBytes: [0xDE, 0xAD])
    XCTAssertEqual(r.encryptedBytes, [0xDE, 0xAD])
  }

  func testStatusWordValueAndDescription() {
    XCTAssertEqual(StatusWord(sw1: 0x90, sw2: 0x00).value, 0x9000)
    XCTAssertEqual(StatusWord(sw1: 0x6A, sw2: 0x82).description, "6A82")
  }
}
