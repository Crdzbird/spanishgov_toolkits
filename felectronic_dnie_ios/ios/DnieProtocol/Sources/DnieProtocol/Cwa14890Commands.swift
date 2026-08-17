import Foundation

/// The APDUs that carry the CWA-14890 handshake to the card.
///
/// Ported from `apdu/iso7816four/*` and `apdu/iso7816eight/*`. These are the
/// messages; ``Cwa14890Authentication`` computes what goes inside them.
///
/// ## Order matters
///
/// The card enforces a sequence, and a step out of place fails in ways that
/// are hard to read from a status word alone:
///
/// 1. `MSE SET` for verification, then `PSO VERIFY CERTIFICATE` for each CVC
///    in the chain, so the card learns the terminal's public key.
/// 2. `MSE SET` naming the card's public key and the terminal's private key
///    reference.
/// 3. `INTERNAL AUTHENTICATE` — the card returns its signed block.
/// 4. `GET CHALLENGE` — the card's random.
/// 5. `EXTERNAL AUTHENTICATE` — the terminal's signed block.
///
/// ## Verification status
///
/// Byte layouts are transcribed from the transpiled Java and covered by tests.
/// The **sequence** above is read from `Cwa14890OneV1Connection.open` and has
/// not been exercised against a card — nothing here has. Ordering bugs are
/// exactly the kind this module cannot catch on its own.
public enum Cwa14890Commands {

  /// `0x22` — MANAGE SECURITY ENVIRONMENT.
  public static let insManageSecurityEnvironment: UInt8 = 0x22
  /// `0x88` — INTERNAL AUTHENTICATE.
  public static let insInternalAuthenticate: UInt8 = 0x88
  /// `0x82` — EXTERNAL AUTHENTICATE.
  public static let insExternalAuthenticate: UInt8 = 0x82
  /// `0x2A` — PERFORM SECURITY OPERATION.
  public static let insPerformSecurityOperation: UInt8 = 0x2A

  /// `0xC1` — P1 for MSE SET when setting up authentication.
  public static let setForAuthentication: UInt8 = 0xC1
  /// `0x41` — P1 for MSE SET when setting up a computation.
  public static let setForComputation: UInt8 = 0x41
  /// `0xA4` — P2 selecting the Authentication Template.
  public static let authenticationTemplate: UInt8 = 0xA4
  /// `0xB6` — P2 selecting the Digital Signature Template.
  public static let digitalSignatureTemplate: UInt8 = 0xB6

  /// `0x83` — tags a public key reference inside a control template.
  public static let publicKeyReferenceTag: UInt8 = 0x83
  /// `0x84` — tags a private key reference.
  public static let privateKeyReferenceTag: UInt8 = 0x84
  /// `0x80` — tags an algorithm reference.
  public static let algorithmReferenceTag: UInt8 = 0x80

  /// Width the public key file identifier is padded to inside the template.
  public static let publicKeyReferenceLength = 12

  // MARK: - MSE SET

  /// Names the key pair the card should use for authentication.
  ///
  /// From `MseSetAuthenticationKeyApduCommand.buidData`:
  ///
  /// ```
  /// 83 0C <public key file id, left-padded to 12 bytes>
  /// 84 LL <private key reference>
  /// ```
  ///
  /// The public key reference is left-padded with zeros to twelve bytes. Note
  /// the Java does not guard against an identifier longer than that — it would
  /// throw from `arraycopy`. This rejects it explicitly instead, since the
  /// resulting template would be malformed either way.
  public static func setAuthenticationKey(
    cla: UInt8 = 0x00, publicKeyFileId: [UInt8], privateKeyReference: [UInt8]
  ) throws -> CommandApdu {
    guard publicKeyFileId.count <= publicKeyReferenceLength else {
      throw SecureChannelError.authenticationFailed(
        "public key file id is \(publicKeyFileId.count) bytes, "
          + "more than the \(publicKeyReferenceLength) the template holds"
      )
    }
    let padded = [UInt8](
      repeating: 0x00, count: publicKeyReferenceLength - publicKeyFileId.count
    ) + publicKeyFileId

    let data =
      [publicKeyReferenceTag, UInt8(publicKeyReferenceLength)] + padded
      + [privateKeyReferenceTag, UInt8(privateKeyReference.count)] + privateKeyReference

    return CommandApdu(
      cla: cla, ins: insManageSecurityEnvironment,
      p1: setForAuthentication, p2: authenticationTemplate, data: data
    )
  }

  /// MSE SET carrying a caller-built authentication template.
  public static func setAuthenticationTemplate(
    cla: UInt8 = 0x00, data: [UInt8]
  ) -> CommandApdu {
    CommandApdu(
      cla: cla, ins: insManageSecurityEnvironment,
      p1: setForAuthentication, p2: authenticationTemplate, data: data
    )
  }

  /// MSE SET for a signature computation — the DST rather than the AT.
  public static func setComputation(cla: UInt8 = 0x00, data: [UInt8]) -> CommandApdu {
    CommandApdu(
      cla: cla, ins: insManageSecurityEnvironment,
      p1: setForComputation, p2: digitalSignatureTemplate, data: data
    )
  }

  // MARK: - The handshake

  /// INTERNAL AUTHENTICATE — asks the card to sign.
  ///
  /// The data field is the terminal's random followed by its private key
  /// reference, concatenated with no tags between them
  /// (`InternalAuthenticateApduCommand.buildData`). P1 and P2 are both zero,
  /// and no `Le` is sent.
  public static func internalAuthenticate(
    cla: UInt8 = 0x00, randomIfd: [UInt8], privateKeyReference: [UInt8]
  ) -> CommandApdu {
    CommandApdu(
      cla: cla, ins: insInternalAuthenticate, p1: 0x00, p2: 0x00,
      data: randomIfd + privateKeyReference
    )
  }

  /// EXTERNAL AUTHENTICATE — presents the terminal's signed block.
  ///
  /// Success is a bare `90 00`; the card returns no data.
  public static func externalAuthenticate(
    cla: UInt8 = 0x00, authenticationToken: [UInt8]
  ) -> CommandApdu {
    CommandApdu(
      cla: cla, ins: insExternalAuthenticate, p1: 0x00, p2: 0x00,
      data: authenticationToken
    )
  }

  /// `0x00` — P1: the card returns no data.
  public static let dataFieldResponseEmpty: UInt8 = 0x00
  /// `0xAE` — P2: the data field holds a certificate to verify.
  public static let dataFieldCommandVerifyCertificate: UInt8 = 0xAE

  /// PSO VERIFY CERTIFICATE — hands the card one card-verifiable certificate.
  ///
  /// Sent once per certificate in the chain, before the key pair is selected.
  public static func verifyCertificate(
    cla: UInt8 = 0x00, certificate: [UInt8]
  ) -> CommandApdu {
    CommandApdu(
      cla: cla, ins: insPerformSecurityOperation,
      p1: dataFieldResponseEmpty, p2: dataFieldCommandVerifyCertificate,
      data: certificate
    )
  }
}
