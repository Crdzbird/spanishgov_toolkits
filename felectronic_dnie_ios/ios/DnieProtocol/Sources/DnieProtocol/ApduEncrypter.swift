import Foundation

/// ISO 7816-4 padding (equivalently ISO 9797-1 padding method 2).
///
/// Transcribed from `AbstractApduEncrypter.addPadding7816` /
/// `removePadding7816`.
public enum Iso7816Padding {
  /// The byte that marks where the real data ends.
  public static let prefix: UInt8 = 0x80

  /// Appends `0x80` then zeros out to the next multiple of `blockSize`.
  ///
  /// Padding is **always** added, even when the input is already block
  /// aligned — a full extra block goes on in that case. That is what makes the
  /// scheme unambiguous, and the Java's `(count / size + 1) * size` produces
  /// exactly this.
  public static func add(_ data: [UInt8], blockSize: Int) -> [UInt8] {
    let padded = (data.count / blockSize + 1) * blockSize
    return data + [prefix] + [UInt8](repeating: 0x00, count: padded - data.count - 1)
  }

  /// Strips ISO 7816-4 padding.
  ///
  /// Scans backwards over trailing zeros looking for `0x80`. Two behaviours
  /// are inherited deliberately from the Java:
  ///
  /// - A `0x80` at offset zero yields empty, not a one-byte result.
  /// - If a non-zero byte other than `0x80` is met first, the input is
  ///   returned **unchanged** rather than treated as an error. Card responses
  ///   are not always padded, and the Java tolerates that.
  public static func remove(_ padded: [UInt8]) -> [UInt8] {
    for i in stride(from: padded.count - 1, through: 0, by: -1) {
      if padded[i] == prefix {
        return i == 0 ? [] : Array(padded[0..<i])
      }
      if padded[i] != 0x00 {
        return padded  // not padded at all
      }
    }
    return padded  // all zeros
  }
}

/// Wraps and unwraps APDUs for the CWA-14890 secure channel.
///
/// Ported from `AbstractApduEncrypter` and `ApduEncrypterDes`. The two
/// concrete variants differ only in how far the MAC is truncated:
/// `Cwa14890OneV1Connection` installs the 4-byte form, `Cwa14890OneV2Connection`
/// the 8-byte one.
///
/// ## Verification status
///
/// The DES and Triple DES primitives are checked against published vectors,
/// and every byte layout here is transcribed from the Java that the working
/// Android build runs. What is **not** verified is the composition against a
/// real card: no DNIe has ever answered any of this. A wrong MAC does not
/// produce a wrong answer, it produces `66 88` and a dead channel, so the
/// first live run will say plainly whether this is right.
public struct ApduEncrypter {

  /// `0x87` — the tag carrying the encrypted data object.
  public static let dataTag: UInt8 = 0x87
  /// `0x97` — the tag carrying the expected response length.
  public static let expectedLengthTag: UInt8 = 0x97
  /// `0x01` — the padding-content indicator prefixed to the cryptogram.
  public static let paddingContentIndicator: UInt8 = 0x01
  /// `0x0C` — OR'd into CLA to mark the APDU as secured.
  public static let protectedClaMask: UInt8 = 0x0C
  /// `0x99` — the tag carrying the response status word.
  public static let statusWordTag: UInt8 = 0x99

  /// How many bytes of the retail MAC are transmitted.
  public let macLength: Int

  /// The 4-byte-MAC variant, used by the DNIe's V1 secure channel.
  public static let des = ApduEncrypter(macLength: 4)
  /// The 8-byte-MAC variant, used by the V2 channel.
  public static let desMac8 = ApduEncrypter(macLength: 8)

  public init(macLength: Int) {
    self.macLength = macLength
  }

  // MARK: - Retail MAC

  /// ISO 9797-1 Algorithm 3 over `sendSequenceCounter ‖ data`.
  ///
  /// From `ApduEncrypterDes.generateMac`. The counter is encrypted first and
  /// becomes the initial chaining value, so the MAC depends on the position of
  /// this APDU in the conversation:
  ///
  /// ```objc
  /// tmpData = desEncrypt(ssc, kMac[0..8]);
  /// while (i < dataPadded.length - 8) {
  ///     tmpData = desEncrypt(xor(tmpData, dataPadded[i..i+8]), kMac[0..8]);
  ///     i += 8;
  /// }
  /// keyTdes = kMac[0..16] ‖ kMac[0..8];
  /// return subArray(desedeEncrypt(xor(tmpData, dataPadded[i..i+8]), keyTdes), 0, macLength);
  /// ```
  ///
  /// The final Triple DES step is what makes this Algorithm 3 rather than a
  /// plain DES CBC-MAC: expanding `E_K1(D_K2(E_K1(x)))` shows the last block
  /// completing the CBC chain under K1, then being re-enciphered under K2 and
  /// K1. That is what defeats the exhaustive search a single-DES MAC would
  /// allow.
  public func mac(
    data paddedData: [UInt8], sendSequenceCounter ssc: [UInt8], macKey: [UInt8]
  ) throws -> [UInt8] {
    guard macKey.count >= 16 else {
      throw DesError.badKeyLength(expected: "at least 16", actual: macKey.count)
    }
    guard !paddedData.isEmpty, paddedData.count % 8 == 0 else {
      throw DesError.notBlockAligned(count: paddedData.count)
    }

    let singleKey = Array(macKey.prefix(8))
    var chain = try Des.encryptBlock(ssc, key: singleKey)

    var i = 0
    while i < paddedData.count - 8 {
      chain = try Des.encryptBlock(
        xor(chain, Array(paddedData[i..<(i + 8)])), key: singleKey
      )
      i += 8
    }

    // K1‖K2‖K1 — the two-key form written out in full.
    let tripleKey = Array(macKey.prefix(16)) + Array(macKey.prefix(8))
    let final = try TripleDes.encrypt(
      xor(chain, Array(paddedData[i..<(i + 8)])), key: tripleKey
    )
    return Array(final.prefix(macLength))
  }

  // MARK: - Protecting a command

  /// The result of securing a command: a new APDU plus the MAC that
  /// authenticates it.
  public struct ProtectedApdu: Equatable, Sendable {
    public let cla: UInt8
    public let ins: UInt8
    public let p1: UInt8
    public let p2: UInt8
    /// The secure-messaging data objects, before the MAC is appended.
    public let dataObjects: [UInt8]
    public let mac: [UInt8]

    /// The complete command as sent, with the `0x8E` checksum appended.
    public func command() throws -> CommandApdu {
      CommandApdu(
        cla: cla, ins: ins, p1: p1, p2: p2,
        data: try SecureMessaging.appendingChecksum(to: dataObjects, mac: mac)
      )
    }
  }

  /// Encrypts and authenticates a command APDU.
  ///
  /// Follows `AbstractApduEncrypter.protectAPDU`. Note that the MAC is
  /// computed over the padded header **concatenated with** the data objects
  /// and then padded again — the header gets its own padding to a block
  /// boundary before the data is appended, which is easy to misread as a
  /// single padding step.
  ///
  /// The caller must advance the send sequence counter before calling this.
  public func protect(
    _ apdu: CommandApdu,
    encryptionKey: [UInt8],
    macKey: [UInt8],
    sendSequenceCounter ssc: SendSequenceCounter
  ) throws -> ProtectedApdu {
    let dataObject = try encryptedDataObject(apdu.data, key: encryptionKey)
    let objects = dataObject + expectedLengthObject(apdu.le)
    let cla = apdu.cla | Self.protectedClaMask

    let header = Iso7816Padding.add([cla, apdu.ins, apdu.p1, apdu.p2], blockSize: 8)
    let macInput = Iso7816Padding.add(header + objects, blockSize: 8)

    return ProtectedApdu(
      cla: cla, ins: apdu.ins, p1: apdu.p1, p2: apdu.p2,
      dataObjects: objects,
      mac: try mac(data: macInput, sendSequenceCounter: ssc.bytes, macKey: macKey)
    )
  }

  /// `87 L 01 ‖ 3DES(pad(data))`, or nothing at all when there is no data.
  func encryptedDataObject(_ data: [UInt8]?, key: [UInt8]) throws -> [UInt8] {
    guard let data, !data.isEmpty else { return [] }
    let cryptogram = try TripleDes.encrypt(
      Iso7816Padding.add(data, blockSize: 8), key: key
    )
    return BerTlv(
      tag: [Self.dataTag], value: [Self.paddingContentIndicator] + cryptogram
    ).encoded
  }

  /// `97 01 Le`, or nothing when the command expects no response body.
  ///
  /// The Java narrows `Le` to a single byte (`le.charValue()`), so an extended
  /// length is truncated rather than encoded in two bytes. Preserved.
  func expectedLengthObject(_ le: Int?) -> [UInt8] {
    guard let le else { return [] }
    return BerTlv(tag: [Self.expectedLengthTag], value: [UInt8(le & 0xFF)]).encoded
  }

  // MARK: - Unwrapping a response

  /// Verifies and decrypts a secure-messaging response.
  ///
  /// From `ApduEncrypterDes.decryptResponseApdu`. The response carries up to
  /// three data objects — `87` the cryptogram, `99` the status word, `8E` the
  /// MAC — of which only the first is optional.
  ///
  /// The MAC is verified **before** anything is decrypted, and a mismatch
  /// throws rather than returning partial data.
  ///
  /// The caller must advance the send sequence counter before calling this.
  public func decrypt(
    response: ResponseApdu,
    encryptionKey: [UInt8],
    macKey: [UInt8],
    sendSequenceCounter ssc: SendSequenceCounter
  ) throws -> ResponseApdu {
    // An unsuccessful response is not wrapped; hand it back untouched.
    guard response.isOk else { return response }

    var dataObject: BerTlv?
    var statusObject: BerTlv?
    var macObject: BerTlv?

    for tlv in (try? BerTlv.decodeAll(response.data)) ?? [] {
      switch UInt8(tlv.tagValue & 0xFF) {
      case Self.dataTag where dataObject == nil: dataObject = tlv
      case Self.statusWordTag where statusObject == nil: statusObject = tlv
      case SecureMessaging.cryptographicChecksumTag where macObject == nil: macObject = tlv
      default: break
      }
    }

    guard let macObject else {
      throw SecureChannelError.missingResponseObject(tag: SecureMessaging.cryptographicChecksumTag)
    }
    guard let statusObject, statusObject.value.count == 2 else {
      throw SecureChannelError.missingResponseObject(tag: Self.statusWordTag)
    }

    // Everything ahead of the 0x8E object is what the MAC covers.
    let macTagIndex = response.data.count - (macObject.value.count + 2)
    guard macTagIndex >= 0 else {
      throw SecureChannelError.missingResponseObject(tag: SecureMessaging.cryptographicChecksumTag)
    }
    let verifiable = Array(response.data[0..<macTagIndex])

    let expected = try mac(
      data: Iso7816Padding.add(verifiable, blockSize: 8),
      sendSequenceCounter: ssc.bytes,
      macKey: macKey
    )
    guard constantTimeEquals(expected, macObject.value) else {
      throw SecureChannelError.invalidCryptographicChecksum
    }

    guard let dataObject else {
      return ResponseApdu(bytes: statusObject.value, encryptedBytes: response.bytes)
    }
    // Drop the leading padding-content indicator before deciphering.
    let cryptogram = Array(dataObject.value.dropFirst())
    let plain = Iso7816Padding.remove(
      try TripleDes.decrypt(cryptogram, key: encryptionKey)
    )
    return ResponseApdu(bytes: plain + statusObject.value, encryptedBytes: response.bytes)
  }
}

// MARK: - Helpers

private func xor(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
  zip(a, b).map(^)
}

/// Compares in time independent of where the first difference falls.
///
/// A MAC comparison that returns early leaks, through timing, how many leading
/// bytes were correct — enough to forge a MAC one byte at a time given enough
/// attempts. The card is not a remote attacker, but this costs nothing.
private func constantTimeEquals(_ a: [UInt8], _ b: [UInt8]) -> Bool {
  guard a.count == b.count else { return false }
  var difference: UInt8 = 0
  for (x, y) in zip(a, b) { difference |= x ^ y }
  return difference == 0
}
