import XCTest
@testable import DnieProtocol

/// PKCS#15 CDF / PrKDF decoding.
///
/// **Scope limit, stated plainly:** these fixtures are built to the PKCS#15
/// ASN.1 that `asn1/der/pkcs15/*.m` declares, not captured from a physical
/// DNIe. They prove the decoder handles the specified shapes, optional-field
/// permutations and padding — they do not prove it handles what a real card
/// emits. Validating against a genuine CDF/PrKDF dump (readily obtainable
/// from the working Android build) remains outstanding before anything
/// depends on this in production.
final class Pkcs15Tests: XCTestCase {

  // MARK: - Minimal DER builder, so fixtures read as structure not hex

  private func tlv(_ tag: UInt8, _ value: [UInt8]) -> [UInt8] {
    BerTlv(tag: [tag], value: value).encoded
  }
  private func seq(_ parts: [UInt8]...) -> [UInt8] {
    tlv(0x30, parts.flatMap { $0 })
  }
  private func ctx(_ n: UInt8, _ parts: [UInt8]...) -> [UInt8] {
    tlv(0xA0 | n, parts.flatMap { $0 })
  }
  private func utf8(_ s: String) -> [UInt8] { tlv(0x0C, Array(s.utf8)) }
  private func octets(_ b: [UInt8]) -> [UInt8] { tlv(0x04, b) }
  private func int(_ v: Int) -> [UInt8] { tlv(0x02, [UInt8(v)]) }

  /// A CertificateObject as the Java models it.
  private func certificateObject(
    label: String, id: [UInt8], path: [UInt8]
  ) -> [UInt8] {
    seq(
      seq(utf8(label)),                   // commonObjectAttributes
      seq(octets(id)),                    // classAttributes: iD
      ctx(1, seq(octets(path)))           // [1] typeAttributes: value = Path
    )
  }

  private func privateKeyObject(
    label: String, id: [UInt8], keyReference: Int, path: [UInt8]
  ) -> [UInt8] {
    seq(
      seq(utf8(label)),                                  // commonObjectAttributes
      seq(octets(id), tlv(0x03, [0x02, 0x74]), int(keyReference)),  // iD, usage, keyRef
      ctx(1, seq(octets(path), int(128)))                // [1] value = Path, modulusLength
    )
  }

  // MARK: - Path

  func testPathDecodesOctetString() throws {
    let bytes = seq(octets([0x3F, 0x00, 0x60, 0x04]))
    let path = try Pkcs15Path.decode(try BerTlv.decode(bytes))
    XCTAssertEqual(path.path, [0x3F, 0x00, 0x60, 0x04])
    XCTAssertEqual(path.hexPath, "3F006004")
    XCTAssertNil(path.index)
  }

  func testPathSplitsIntoFileIdentifiers() throws {
    let bytes = seq(octets([0x3F, 0x00, 0x60, 0x04, 0x70, 0x01]))
    let path = try Pkcs15Path.decode(try BerTlv.decode(bytes))
    XCTAssertEqual(path.fileIds, [[0x3F, 0x00], [0x60, 0x04], [0x70, 0x01]])
  }

  func testPathWithOptionalIndex() throws {
    let bytes = seq(octets([0x3F, 0x00]), int(2))
    let path = try Pkcs15Path.decode(try BerTlv.decode(bytes))
    XCTAssertEqual(path.index, 2)
  }

  func testPathRejectsMissingOctetString() {
    let bytes = seq(int(1))
    XCTAssertThrowsError(try Pkcs15Path.decode(try BerTlv.decode(bytes))) { e in
      XCTAssertEqual(e as? Pkcs15Error, .missingField("Path.path"))
    }
  }

  // MARK: - CDF

  func testSingleCertificate() throws {
    let cdf = try Pkcs15Cdf.decode(
      certificateObject(label: "CertFirmaDigital", id: [0x01], path: [0x3F, 0x00, 0x60, 0x04])
    )
    XCTAssertEqual(cdf.count, 1)
    XCTAssertEqual(cdf.certificates[0].label, "CertFirmaDigital")
    XCTAssertEqual(cdf.certificates[0].identifier, [0x01])
    XCTAssertEqual(cdf.certificates[0].path.hexPath, "3F006004")
  }

  /// A DNIe carries a signature certificate and an authentication certificate.
  func testMultipleCertificatesInOneFile() throws {
    var bytes = certificateObject(label: "CertFirmaDigital", id: [0x01], path: [0x3F, 0x00, 0x60, 0x04])
    bytes += certificateObject(label: "CertAutenticacion", id: [0x02], path: [0x3F, 0x00, 0x60, 0x05])

    let cdf = try Pkcs15Cdf.decode(bytes)
    XCTAssertEqual(cdf.count, 2)
    XCTAssertEqual(cdf.certificates.map(\.label), ["CertFirmaDigital", "CertAutenticacion"])
    XCTAssertEqual(cdf.certificates[1].path.hexPath, "3F006005")
  }

  func testTrailingPaddingEndsParsingCleanly() throws {
    var bytes = certificateObject(label: "Cert", id: [0x01], path: [0x3F, 0x00])
    bytes += [UInt8](repeating: 0xFF, count: 32)   // common card padding
    let cdf = try Pkcs15Cdf.decode(bytes)
    XCTAssertEqual(cdf.count, 1)

    var zeroPadded = certificateObject(label: "Cert", id: [0x01], path: [0x3F, 0x00])
    zeroPadded += [UInt8](repeating: 0x00, count: 16)
    XCTAssertEqual(try Pkcs15Cdf.decode(zeroPadded).count, 1)
  }

  func testEmptyFileYieldsNoCertificates() throws {
    XCTAssertEqual(try Pkcs15Cdf.decode([]).count, 0)
    XCTAssertEqual(try Pkcs15Cdf.decode([0xFF, 0xFF]).count, 0)
  }

  func testTruncatedRecordStopsWithoutThrowing() throws {
    var bytes = certificateObject(label: "Good", id: [0x01], path: [0x3F, 0x00])
    bytes += [0x30, 0x7F, 0x01]  // claims 127 bytes, supplies one
    let cdf = try Pkcs15Cdf.decode(bytes)
    XCTAssertEqual(cdf.count, 1)
    XCTAssertEqual(cdf.certificates[0].label, "Good")
  }

  func testCertificateWithoutLabelStillDecodes() throws {
    let bytes = seq(seq(), seq(octets([0x07])), ctx(1, seq(octets([0x3F, 0x00]))))
    let cdf = try Pkcs15Cdf.decode(bytes)
    XCTAssertEqual(cdf.count, 1)
    XCTAssertNil(cdf.certificates[0].label)
    XCTAssertEqual(cdf.certificates[0].identifier, [0x07])
  }

  // MARK: - PrKDF

  func testPrivateKeyDecoding() throws {
    let prkdf = try Pkcs15PrKdf.decode(
      privateKeyObject(label: "KprivFirmaDigital", id: [0x01], keyReference: 0x02, path: [0x3F, 0x00, 0x50, 0x15])
    )
    XCTAssertEqual(prkdf.count, 1)
    let key = prkdf.keys[0]
    XCTAssertEqual(key.label, "KprivFirmaDigital")
    XCTAssertEqual(key.identifier, [0x01])
    XCTAssertEqual(key.keyReference, 0x02)
    XCTAssertEqual(key.path?.hexPath, "3F005015")
  }

  /// The pairing that makes signing work: a certificate and its key share an
  /// identifier.
  func testKeyIsMatchedToCertificateByIdentifier() throws {
    var cdfBytes = certificateObject(label: "CertFirmaDigital", id: [0x01], path: [0x3F, 0x00, 0x60, 0x04])
    cdfBytes += certificateObject(label: "CertAutenticacion", id: [0x02], path: [0x3F, 0x00, 0x60, 0x05])

    var prkBytes = privateKeyObject(label: "KprivFirmaDigital", id: [0x01], keyReference: 0x02, path: [0x3F, 0x00])
    prkBytes += privateKeyObject(label: "KprivAutenticacion", id: [0x02], keyReference: 0x03, path: [0x3F, 0x00])

    let cdf = try Pkcs15Cdf.decode(cdfBytes)
    let prkdf = try Pkcs15PrKdf.decode(prkBytes)

    let signing = cdf.certificates[0]
    XCTAssertEqual(prkdf.key(matching: signing)?.label, "KprivFirmaDigital")
    XCTAssertEqual(prkdf.key(matching: signing)?.keyReference, 0x02)

    let auth = cdf.certificates[1]
    XCTAssertEqual(prkdf.key(matching: auth)?.keyReference, 0x03)
  }

  func testUnmatchedCertificateYieldsNoKey() throws {
    let cdf = try Pkcs15Cdf.decode(certificateObject(label: "Orphan", id: [0x09], path: [0x3F, 0x00]))
    let prkdf = try Pkcs15PrKdf.decode(privateKeyObject(label: "K", id: [0x01], keyReference: 1, path: [0x3F, 0x00]))
    XCTAssertNil(prkdf.key(matching: cdf.certificates[0]))
  }

  func testKeyWithoutReferenceDecodes() throws {
    let bytes = seq(seq(utf8("K")), seq(octets([0x01])), ctx(1, seq(octets([0x3F, 0x00]))))
    let prkdf = try Pkcs15PrKdf.decode(bytes)
    XCTAssertEqual(prkdf.count, 1)
    XCTAssertNil(prkdf.keys[0].keyReference)
  }

  // MARK: - Multi-byte tags, the Stage 1 divergence, exercised on real shapes

  /// The decoder must survive structures carrying multi-byte tags, which
  /// jmulticard's single-byte tag reader could not represent. `7F 49` is the
  /// CVC public-key tag that Stage 3 will need.
  func testMultiByteTagInsideAStructureIsSkippedNotMisparsed() throws {
    var bytes = seq(
      seq(utf8("Cert")),
      seq(octets([0x01])),
      ctx(1, seq(octets([0x3F, 0x00])))
    )
    bytes += BerTlv(tag: [0x7F, 0x49], value: [0xAA, 0xBB]).encoded

    let cdf = try Pkcs15Cdf.decode(bytes)
    // The certificate parses, and the CVC-tagged record is read as its own
    // object rather than corrupting the stream.
    XCTAssertEqual(cdf.count, 1)
    XCTAssertEqual(cdf.certificates[0].label, "Cert")
  }
}
