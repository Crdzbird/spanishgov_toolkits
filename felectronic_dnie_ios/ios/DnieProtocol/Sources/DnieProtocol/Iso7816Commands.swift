import Foundation

/// ISO 7816-4 command constructors.
///
/// Each instruction byte and parameter is transcribed from the corresponding
/// class in `jmulticard-objc/es/gob/jmulticard/apdu/iso7816four/`. The Java
/// declares them as signed bytes, so the transpiled constants appear negative
/// — `INS_GET_CHALLENGE = -124` is `0x84`, `INS_GET_RESPONSE = -64` is `0xC0`,
/// `INS_SELECT_FILE = -92` is `0xA4`. The unsigned values are used here and
/// asserted in the tests.
public enum Iso7816 {

  /// Instruction bytes, named as in the Java.
  public enum Ins {
    /// `GetChallengeApduCommand.INS_GET_CHALLENGE` (-124)
    public static let getChallenge: UInt8 = 0x84
    /// `GetResponseApduCommand.INS_GET_RESPONSE` (-64)
    public static let getResponse: UInt8 = 0xC0
    /// `SelectFileByIdApduCommand.INS_SELECT_FILE` (-92)
    public static let selectFile: UInt8 = 0xA4
  }

  /// `GetChallengeApduCommand.DEFAULT_LE`
  public static let defaultChallengeLength = 8

  /// GET CHALLENGE — asks the card for `length` random bytes.
  ///
  /// jmulticard: `cla, INS_GET_CHALLENGE, 0x00, 0x00, null, Integer(numBytes)`.
  public static func getChallenge(
    cla: UInt8,
    length: Int = defaultChallengeLength
  ) -> CommandApdu {
    CommandApdu(cla: cla, ins: Ins.getChallenge, p1: 0x00, p2: 0x00, data: nil, le: length)
  }

  /// GET RESPONSE — retrieves `length` bytes the card reported as pending,
  /// typically after a `61 xx` status word.
  ///
  /// jmulticard: `cla, INS_GET_RESPONSE, 0x00, 0x00, null, Integer(le)`.
  public static func getResponse(cla: UInt8, length: Int) -> CommandApdu {
    CommandApdu(cla: cla, ins: Ins.getResponse, p1: 0x00, p2: 0x00, data: nil, le: length)
  }

  /// SELECT FILE by identifier.
  ///
  /// jmulticard: `cla, INS_SELECT_FILE, SELECT_BY_ID (0x00), SEARCH_FIRST
  /// (0x00), fileId, null` — note it sends no `Le`.
  public static func selectFileById(cla: UInt8, fileId: [UInt8]) -> CommandApdu {
    CommandApdu(cla: cla, ins: Ins.selectFile, p1: 0x00, p2: 0x00, data: fileId, le: nil)
  }
}
