import Foundation

/// Something that can exchange an APDU with a card.
///
/// Injected so the read loop can be driven by a fake in tests. In the plugin
/// this is backed by CoreNFC; once the secure channel is open it is backed by
/// ``ApduEncrypter``, which wraps and unwraps transparently.
public protocol ApduTransport {
  func transmit(_ command: CommandApdu) throws -> ResponseApdu
}

/// Status words ISO 7816-4 file access turns on.
public extension StatusWord {
  /// `69 82` — the operation needs a security state the card is not in.
  /// During file reading this usually means the secure channel is not open.
  static let unsatisfiedSecurityState = StatusWord(sw1: 0x69, sw2: 0x82)
  /// `6A 82` — no such file.
  static let fileNotFound = StatusWord(sw1: 0x6A, sw2: 0x82)
  /// `62 82` — the read ran past the end of the file. Not an error: it means
  /// what was returned is the tail of the file.
  static let endOfFileReached = StatusWord(sw1: 0x62, sw2: 0x82)
  /// `6B 00` — the requested offset is outside the file.
  static let offsetOutsideFile = StatusWord(sw1: 0x6B, sw2: 0x00)
}

public enum FileAccessError: Error, Equatable, Sendable {
  case fileNotFound(id: [UInt8])
  case securityStateNotSatisfied
  case unexpectedStatus(StatusWord)
  case malformedFileControlInformation(String)
}

// MARK: - Commands

/// The ISO 7816-4 commands used to walk the card's file system and to sign.
public enum Iso7816FileCommands {

  /// `0xB0` — READ BINARY.
  public static let insReadBinary: UInt8 = 0xB0
  /// `0xA4` — SELECT FILE.
  public static let insSelectFile: UInt8 = 0xA4
  /// `0xC0` — GET RESPONSE.
  public static let insGetResponse: UInt8 = 0xC0
  /// `0x2A` — PERFORM SECURITY OPERATION.
  public static let insPerformSecurityOperation: UInt8 = 0x2A

  /// `0x04` — P1 selecting a DF by name.
  public static let selectDfByName: UInt8 = 0x04
  /// `0x9E` — P1 for PSO: the response is a signature.
  public static let dataFieldSignOperation: UInt8 = 0x9E
  /// `0x9A` — P2 for PSO: the data field is a hash to sign.
  public static let dataFieldSignHash: UInt8 = 0x9A

  /// Largest body the card will return in one READ BINARY.
  ///
  /// `AbstractIso7816FourCard.MAX_READ_CHUNK` is 222 — not 255. The margin
  /// leaves room for secure-messaging overhead, which would otherwise push the
  /// wrapped response past what the card can return.
  public static let maxReadChunk = 222

  /// READ BINARY at a byte offset. The offset is split across P1 and P2.
  public static func readBinary(
    cla: UInt8 = 0x00, offset: Int, length: Int
  ) -> CommandApdu {
    CommandApdu(
      cla: cla, ins: insReadBinary,
      p1: UInt8((offset >> 8) & 0xFF), p2: UInt8(offset & 0xFF),
      data: nil, le: length
    )
  }

  /// SELECT FILE by DF name (an AID).
  public static func selectDfByName(cla: UInt8 = 0x00, name: [UInt8]) -> CommandApdu {
    CommandApdu(
      cla: cla, ins: insSelectFile, p1: selectDfByName, p2: 0x00, data: name
    )
  }

  /// GET RESPONSE, for cards that answer `61 xx`.
  public static func getResponse(cla: UInt8 = 0x00, length: Int) -> CommandApdu {
    CommandApdu(cla: cla, ins: insGetResponse, p1: 0x00, p2: 0x00, data: nil, le: length)
  }

  /// PSO SIGN HASH — asks the card to sign an already-built DigestInfo.
  ///
  /// The card signs what it is given; it does not hash. `digestInfo` is the
  /// full DER `DigestInfo` (algorithm identifier plus digest), not a bare
  /// hash, and building it wrongly produces a signature that verifies against
  /// nothing.
  public static func signHash(cla: UInt8 = 0x00, digestInfo: [UInt8]) -> CommandApdu {
    CommandApdu(
      cla: cla, ins: insPerformSecurityOperation,
      p1: dataFieldSignOperation, p2: dataFieldSignHash, data: digestInfo
    )
  }
}

// MARK: - File control information

/// What a SELECT FILE response says about the file.
///
/// Decoded from the FCI template (`0x6F`), following
/// `SelectFileApduResponse.decode`.
public struct FileControlInformation: Equatable, Sendable {
  /// Length of the file body, from the `0x81` descriptor.
  public let fileLength: Int
  public let fileId: [UInt8]?
  public let dfName: [UInt8]?

  /// Decodes the FCI from a SELECT FILE response body.
  ///
  /// ## A quirk preserved from the Java, deliberately
  ///
  /// `SelectFileApduResponse.decode` tests for tag `0x81` **twice** in
  /// sequence — once for the file length, then again for what it assigns to
  /// `fileId`. Since the first branch consumes the only `0x81` a well-formed
  /// FCI carries, the second can never fire; ISO 7816-4 tags the file
  /// identifier `0x83`. That looks like a defect in jmulticard rather than a
  /// card quirk.
  ///
  /// It is reproduced here rather than corrected, because the Android build
  /// works with this behaviour and "fixing" it would change which bytes land
  /// in `fileId` on a card whose FCI I cannot inspect. ``fileId`` therefore
  /// comes only from the `0x85` descriptor in practice. If a real card shows
  /// otherwise, this is the first place to look.
  public static func decode(_ data: [UInt8]) throws -> FileControlInformation {
    guard data.count > 2, data[0] == 0x6F else {
      throw FileAccessError.malformedFileControlInformation(
        "expected an FCI template (0x6F), got \(data.first.map { String($0, radix: 16) } ?? "nothing")"
      )
    }
    // The Java only decodes when the declared length matches exactly.
    guard data.count - 2 == Int(data[1]) else {
      throw FileAccessError.malformedFileControlInformation(
        "declared length \(Int(data[1])) does not match the \(data.count - 2) bytes present"
      )
    }

    var index = 2
    var fileLength = 0
    var fileId: [UInt8]?
    var dfName: [UInt8]?

    func take(_ count: Int) -> [UInt8]? {
      guard index + count <= data.count else { return nil }
      defer { index += count }
      return Array(data[index..<(index + count)])
    }

    if index < data.count, data[index] == 0x81 {
      index += 1
      guard let lengthLength = take(1)?.first,
            let value = take(Int(lengthLength)), value.count >= 2
      else {
        throw FileAccessError.malformedFileControlInformation("truncated 0x81 descriptor")
      }
      fileLength = Int(value[0]) << 8 | Int(value[1])
    }

    // See the note above: this second 0x81 is unreachable on a well-formed
    // FCI, and is kept only to match the Java byte for byte.
    if index < data.count, data[index] == 0x81 {
      index += 1
      if let idLength = take(1)?.first { fileId = take(Int(idLength)) }
    }

    if index < data.count, data[index] == 0x84 {
      index += 1
      if let nameLength = take(1)?.first { dfName = take(Int(nameLength)) }
    }

    if index + 1 < data.count, data[index] == 0x85 {
      let length = Int(data[index + 1])
      if length >= 2, index + 2 + length <= data.count {
        fileId = Array(data[(index + 2)..<(index + 4)])
      }
    }

    return FileControlInformation(fileLength: fileLength, fileId: fileId, dfName: dfName)
  }
}

// MARK: - Reading a file

/// Selects files and reads them whole.
public struct Iso7816FileReader {
  private let transport: ApduTransport
  private let cla: UInt8

  public init(transport: ApduTransport, cla: UInt8 = 0x00) {
    self.transport = transport
    self.cla = cla
  }

  /// Selects a file by identifier and returns what the card says about it.
  public func select(fileId: [UInt8]) throws -> FileControlInformation {
    let response = try transport.transmit(
      CommandApdu(cla: cla, ins: Iso7816FileCommands.insSelectFile,
                  p1: 0x00, p2: 0x00, data: fileId)
    )
    switch response.statusWord {
    case .some(.fileNotFound):
      throw FileAccessError.fileNotFound(id: fileId)
    case .some(.unsatisfiedSecurityState):
      throw FileAccessError.securityStateNotSatisfied
    case .some(let sw) where !sw.isOk:
      throw FileAccessError.unexpectedStatus(sw)
    default:
      break
    }
    return try FileControlInformation.decode(response.data)
  }

  /// Reads `length` bytes from the currently selected file.
  ///
  /// From `AbstractIso7816FourCard.readBinaryComplete`. Three behaviours are
  /// inherited on purpose:
  ///
  /// - `62 82` (end of file) is **not** an error. The data returned with it is
  ///   kept and the loop stops — that is how a file shorter than its declared
  ///   length terminates.
  /// - Reading past the end returns what was gathered so far rather than
  ///   throwing, matching the Java, which logs a warning and returns.
  /// - The offset advances by the full chunk size even after a short final
  ///   read. Harmless, since the loop then exits, but it is why the offset can
  ///   end up past `length`.
  public func readBinary(length: Int) throws -> [UInt8] {
    var out: [UInt8] = []
    var offset = 0

    while offset < length {
      let remaining = length - offset
      let chunk = min(remaining, Iso7816FileCommands.maxReadChunk)

      let response: ResponseApdu
      do {
        response = try transport.transmit(
          Iso7816FileCommands.readBinary(cla: cla, offset: offset, length: chunk)
        )
      } catch {
        // The Java swallows an out-of-bounds read and returns what it has.
        return out
      }

      guard let statusWord = response.statusWord else { return out }
      let atEnd = statusWord == .endOfFileReached

      if !statusWord.isOk && !atEnd {
        if statusWord == .offsetOutsideFile { return out }
        throw FileAccessError.unexpectedStatus(statusWord)
      }

      out += response.data
      offset += Iso7816FileCommands.maxReadChunk
      if atEnd { break }
    }

    return out
  }

  /// Selects a file and reads it in one step — the common case.
  public func selectAndRead(fileId: [UInt8]) throws -> [UInt8] {
    let fci = try select(fileId: fileId)
    return try readBinary(length: fci.fileLength)
  }
}
