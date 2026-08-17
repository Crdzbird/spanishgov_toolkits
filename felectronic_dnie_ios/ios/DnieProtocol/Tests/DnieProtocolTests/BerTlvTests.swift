import XCTest
@testable import DnieProtocol

/// BER-TLV decoding, per X.690.
///
/// `es.gob.jmulticard.asn1.Tlv` decodes lengths the same way; this decoder
/// additionally handles multi-byte tags (needed for CVC from Stage 3) and
/// rejects the indefinite form, which is illegal in the DER that cards use.
/// See the note on `BerTlv` — including the correction of an earlier, wrong
/// claim that jmulticard's length handling was non-standard.
final class BerTlvTests: XCTestCase {

  func testShortFormPrimitive() throws {
    let tlv = try BerTlv.decode([0x80, 0x03, 0x01, 0x02, 0x03])
    XCTAssertEqual(tlv.tagValue, 0x80)
    XCTAssertEqual(tlv.value, [0x01, 0x02, 0x03])
    XCTAssertEqual(tlv.endOffset, 5)
    XCTAssertFalse(tlv.isConstructed)
  }

  func testEmptyValue() throws {
    let tlv = try BerTlv.decode([0x80, 0x00])
    XCTAssertEqual(tlv.value, [])
    XCTAssertEqual(tlv.endOffset, 2)
  }

  func testLongFormLength() throws {
    // 0x81 => one length byte follows.
    var bytes: [UInt8] = [0x04, 0x81, 0x80]
    bytes.append(contentsOf: [UInt8](repeating: 0xAA, count: 0x80))
    let tlv = try BerTlv.decode(bytes)
    XCTAssertEqual(tlv.value.count, 0x80)
    XCTAssertEqual(tlv.endOffset, bytes.count)
  }

  func testTwoByteLength() throws {
    var bytes: [UInt8] = [0x04, 0x82, 0x01, 0x00]
    bytes.append(contentsOf: [UInt8](repeating: 0xBB, count: 256))
    let tlv = try BerTlv.decode(bytes)
    XCTAssertEqual(tlv.value.count, 256)
  }

  /// Low five bits set means the tag continues; continuation bytes have bit 7
  /// set while more follow.
  func testMultiByteTag() throws {
    let tlv = try BerTlv.decode([0x7F, 0x49, 0x02, 0xAA, 0xBB])
    XCTAssertEqual(tlv.tag, [0x7F, 0x49])
    XCTAssertEqual(tlv.tagValue, 0x7F49)
    XCTAssertEqual(tlv.value, [0xAA, 0xBB])
    XCTAssertTrue(tlv.isConstructed)  // 0x7F has 0x20 set
  }

  func testConstructedChildren() throws {
    // 6F 06 [ 80 01 AA, 81 01 BB ]
    let tlv = try BerTlv.decode([0x6F, 0x06, 0x80, 0x01, 0xAA, 0x81, 0x01, 0xBB])
    XCTAssertTrue(tlv.isConstructed)
    let kids = try tlv.children()
    XCTAssertEqual(kids.count, 2)
    XCTAssertEqual(kids[0].tagValue, 0x80)
    XCTAssertEqual(kids[0].value, [0xAA])
    XCTAssertEqual(kids[1].tagValue, 0x81)
    XCTAssertEqual(kids[1].value, [0xBB])
  }

  func testDecodeAllSequential() throws {
    let all = try BerTlv.decodeAll([0x80, 0x01, 0x01, 0x81, 0x02, 0x02, 0x03])
    XCTAssertEqual(all.count, 2)
    XCTAssertEqual(all[0].value, [0x01])
    XCTAssertEqual(all[1].value, [0x02, 0x03])
  }

  func testDepthFirstSearch() throws {
    let tlv = try BerTlv.decode([0x6F, 0x06, 0x80, 0x01, 0xAA, 0x81, 0x01, 0xBB])
    XCTAssertEqual(try tlv.first(tag: 0x81)?.value, [0xBB])
    XCTAssertNil(try tlv.first(tag: 0x9F))
  }

  func testRoundTripEncoding() throws {
    for count in [0, 1, 127, 128, 255, 256] {
      let value = [UInt8](repeating: 0x5A, count: count)
      let original = BerTlv(tag: [0x04], value: value)
      let decoded = try BerTlv.decode(original.encoded)
      XCTAssertEqual(decoded.value, value, "round trip failed at length \(count)")
      XCTAssertEqual(decoded.tagValue, 0x04)
    }
  }

  // --- Malformed input is rejected rather than trapping.

  func testTruncatedValue() {
    XCTAssertThrowsError(try BerTlv.decode([0x80, 0x05, 0x01])) { error in
      XCTAssertEqual(error as? BerTlvError, .truncated(atOffset: 2))
    }
  }

  func testTruncatedTag() {
    XCTAssertThrowsError(try BerTlv.decode([0x7F]))
  }

  func testMissingLength() {
    XCTAssertThrowsError(try BerTlv.decode([0x80]))
  }

  func testIndefiniteLengthRejected() {
    // 0x80 as a length byte is the indefinite form, invalid in DER.
    XCTAssertThrowsError(try BerTlv.decode([0x30, 0x80, 0x00, 0x00])) { error in
      XCTAssertEqual(
        error as? BerTlvError,
        .unsupportedLengthForm(firstByte: 0x80, atOffset: 1)
      )
    }
  }

  func testEmptyInput() {
    XCTAssertThrowsError(try BerTlv.decode([]))
    XCTAssertEqual(try? BerTlv.decodeAll([]), [])
  }
}
