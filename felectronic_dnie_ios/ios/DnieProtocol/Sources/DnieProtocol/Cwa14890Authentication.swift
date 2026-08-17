import CryptoKit
import Foundation
import Security

/// The CWA-14890 mutual authentication exchange.
///
/// Two halves, each carrying 32 bytes of key material:
///
/// - **Internal authentication** — the card signs a block containing its half,
///   `Kicc`, which the terminal recovers and verifies.
/// - **External authentication** — the terminal signs a block containing its
///   half, `Kifd`, which the card verifies.
///
/// The session seed is `Kicc XOR Kifd`, so neither side alone determines the
/// session keys. Both blocks are ISO 9796-2 signatures with message recovery:
/// the signed data *is* the message, recovered by applying the public
/// exponent.
///
/// ```
/// 6A ‖ PRND ‖ K ‖ SHA1(PRND ‖ K ‖ challenge ‖ identifier) ‖ BC
/// ```
///
/// ## Verification status — read before trusting this
///
/// This is the one part of the secure channel with **no external anchor**.
/// The layout below is transcribed from the transpiled Java, and the tests
/// exercise it against a real RSA key pair generated at test time, which
/// proves the two directions agree with each other and that recovery inverts
/// construction. It does **not** prove a DNIe agrees, because a card has never
/// answered any of it. A self-consistent misreading of the Java would pass
/// every test here.
///
/// Two further pieces are still missing before this can run against hardware:
/// the card-verifiable certificates and the terminal's private key
/// (`CA_PUBLIC_KEY`, `CA_COMPONENT_PUBLIC_KEY`, `IfdPrivateKey` and the CVC
/// blobs), which must be byte-exact; and the `MSE SET` / `INTERNAL
/// AUTHENTICATE` / `EXTERNAL AUTHENTICATE` command sequence that carries these
/// messages to the card.
public enum Cwa14890Authentication {

  /// `0x6A` — opens an ISO 9796-2 recoverable message.
  public static let paddingStart: UInt8 = 0x6A
  /// `0xBC` — closes it, and identifies the hash as SHA-1.
  public static let paddingEnd: UInt8 = 0xBC

  /// Bytes of key material contributed by each side.
  public static let keyMaterialLength = 32
  /// SHA-1 output length.
  public static let digestLength = 20

  /// Overhead around `PRND`: the two padding bytes, the key material and the
  /// digest. `PRND` fills whatever the modulus leaves over.
  static var fixedOverhead: Int { 2 + keyMaterialLength + digestLength }

  // MARK: - Internal authentication: recovering the card's half

  /// Recovers and verifies `Kicc` from the card's signature.
  ///
  /// From `internalAuthValidateInternalAuthenticateMessage`. The card's reply
  /// is signed with the terminal's public key over the card's private key, so
  /// unwrapping is: apply the terminal's private exponent, then the card's
  /// public exponent.
  ///
  /// If the result is not a well-formed ISO 9796-2 block, the value is
  /// reflected about the card's modulus and tried once more. That second
  /// attempt is not a fallback for corrupt data — it is required by the
  /// scheme, which transmits `min(sig, n - sig)` so the signature always fits
  /// below the modulus.
  ///
  /// - Throws: ``SecureChannelError/authenticationFailed(_:)`` if neither form
  ///   parses or the recovered digest does not match.
  public static func recoverCardKeyMaterial(
    signature: [UInt8],
    randomIfd: [UInt8],
    terminalCertificateReference chrCCvIfd: [UInt8],
    terminalKey: RsaRawCipher,
    cardKey: RsaRawCipher
  ) throws -> [UInt8] {
    let unwrapped = try terminalKey.privateOperation(signature)
    var recovered = try cardKey.publicOperation(unwrapped)

    if !isWellFormed(recovered) {
      // Reflect about the modulus: n - sig.
      let reflected = BigEndian.subtract(
        cardKey.modulus, BigEndian.stripLeadingZeros(unwrapped),
        width: terminalKey.modulusLength
      )
      recovered = try cardKey.publicOperation(reflected)
      guard isWellFormed(recovered) else {
        throw SecureChannelError.authenticationFailed(
          "the card's signature is not a valid ISO 9796-2 block in either form"
        )
      }
    }

    let parts = try split(recovered)
    let expected = digest(
      prnd: parts.prnd, keyMaterial: parts.keyMaterial,
      challenge: randomIfd, identifier: chrCCvIfd
    )
    guard constantTimeEquals(parts.digest, expected) else {
      throw SecureChannelError.authenticationFailed(
        "the digest recovered from the card does not match"
      )
    }
    return parts.keyMaterial
  }

  // MARK: - External authentication: presenting the terminal's half

  /// The terminal's signed block, together with the key material inside it.
  public struct ExternalAuthentication: Equatable, Sendable {
    /// The bytes to send in EXTERNAL AUTHENTICATE.
    public let message: [UInt8]
    /// `Kifd` — the terminal's contribution to the session seed.
    public let keyMaterial: [UInt8]
  }

  /// Builds the EXTERNAL AUTHENTICATE payload.
  ///
  /// From `externalAuthentication`. `prnd2` and `kifd` are random per
  /// exchange; they are parameters rather than generated internally so the
  /// construction can be tested deterministically. ``generate(...)`` is the
  /// entry point that draws them from the system generator.
  public static func buildExternalAuthentication(
    prnd: [UInt8],
    keyMaterial kifd: [UInt8],
    randomIcc: [UInt8],
    paddedSerial serial: [UInt8],
    terminalKey: RsaRawCipher,
    cardKey: RsaRawCipher
  ) throws -> ExternalAuthentication {
    guard kifd.count == keyMaterialLength else {
      throw SecureChannelError.authenticationFailed(
        "Kifd must be \(keyMaterialLength) bytes, got \(kifd.count)"
      )
    }

    let hash = digest(
      prnd: prnd, keyMaterial: kifd, challenge: randomIcc, identifier: serial
    )
    let block = [paddingStart] + prnd + kifd + hash + [paddingEnd]

    let signature = try terminalKey.privateOperation(block)

    // Transmit whichever of sig and n - sig is smaller, so the value is
    // unambiguously below the modulus. The card reverses this by trying both.
    let reflected = BigEndian.subtract(
      terminalKey.modulus, BigEndian.stripLeadingZeros(signature),
      width: terminalKey.modulusLength
    )
    let smaller = BigEndian.compare(signature, reflected) == .orderedDescending
      ? reflected : signature

    return ExternalAuthentication(
      message: try cardKey.publicOperation(smaller),
      keyMaterial: kifd
    )
  }

  /// Draws fresh randomness and builds the payload.
  ///
  /// `PRND` fills the modulus once the fixed fields are accounted for.
  public static func generate(
    randomIcc: [UInt8],
    paddedSerial serial: [UInt8],
    terminalKey: RsaRawCipher,
    cardKey: RsaRawCipher
  ) throws -> ExternalAuthentication {
    let prndLength = terminalKey.modulusLength - fixedOverhead
    guard prndLength > 0 else {
      throw SecureChannelError.authenticationFailed(
        "modulus of \(terminalKey.modulusLength) bytes is too small for the scheme"
      )
    }
    return try buildExternalAuthentication(
      prnd: try randomBytes(prndLength),
      keyMaterial: try randomBytes(keyMaterialLength),
      randomIcc: randomIcc,
      paddedSerial: serial,
      terminalKey: terminalKey,
      cardKey: cardKey
    )
  }

  // MARK: - Deriving the session

  /// Combines both halves into the seed the session keys come from.
  ///
  /// `Kicc XOR Kifd`, per `open()`. Feed the result to
  /// ``Cwa14890KeyDerivation``.
  public static func sessionSeed(cardKeyMaterial kicc: [UInt8], terminalKeyMaterial kifd: [UInt8]) throws -> [UInt8] {
    guard kicc.count == keyMaterialLength, kifd.count == keyMaterialLength else {
      throw SecureChannelError.authenticationFailed(
        "both halves must be \(keyMaterialLength) bytes"
      )
    }
    return zip(kicc, kifd).map(^)
  }

  /// Left-pads the card serial to eight bytes.
  ///
  /// From `getPaddedSerial`. A serial already eight bytes or longer is passed
  /// through unchanged — the Java does not truncate, and neither does this.
  public static func paddedSerial(_ serial: [UInt8]) -> [UInt8] {
    serial.count >= 8
      ? serial
      : [UInt8](repeating: 0x00, count: 8 - serial.count) + serial
  }

  // MARK: - Block layout

  static func isWellFormed(_ block: [UInt8]) -> Bool {
    guard block.count > fixedOverhead else { return false }
    return block.first == paddingStart && block.last == paddingEnd
  }

  struct RecoveredBlock {
    let prnd: [UInt8]
    let keyMaterial: [UInt8]
    let digest: [UInt8]
  }

  /// Splits `6A ‖ PRND ‖ K ‖ H ‖ BC`. `PRND` is whatever is left over, which
  /// is how the Java sizes it: `modulusLength - 32 - 20 - 2`.
  static func split(_ block: [UInt8]) throws -> RecoveredBlock {
    let prndLength = block.count - fixedOverhead
    guard prndLength > 0 else {
      throw SecureChannelError.authenticationFailed("recovered block is too short")
    }
    var offset = 1
    let prnd = Array(block[offset..<(offset + prndLength)])
    offset += prndLength
    let keyMaterial = Array(block[offset..<(offset + keyMaterialLength)])
    offset += keyMaterialLength
    let digest = Array(block[offset..<(offset + digestLength)])
    return RecoveredBlock(prnd: prnd, keyMaterial: keyMaterial, digest: digest)
  }

  /// `SHA1(PRND ‖ K ‖ challenge ‖ identifier)`.
  ///
  /// Binding the challenge is what stops a recorded exchange being replayed;
  /// binding the identifier is what stops it being redirected to a different
  /// terminal or card.
  static func digest(
    prnd: [UInt8], keyMaterial: [UInt8], challenge: [UInt8], identifier: [UInt8]
  ) -> [UInt8] {
    var hasher = Insecure.SHA1()
    hasher.update(data: prnd)
    hasher.update(data: keyMaterial)
    hasher.update(data: challenge)
    hasher.update(data: identifier)
    return Array(hasher.finalize())
  }

  /// Draws from the system CSPRNG.
  ///
  /// `Kifd` is half the session seed, so its unpredictability is what the
  /// channel's confidentiality rests on. `SecRandomCopyBytes` is used rather
  /// than Swift's `random(in:)`, whose generator carries no cryptographic
  /// guarantee, and a failure throws rather than falling back to anything
  /// weaker.
  static func randomBytes(_ count: Int) throws -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: count)
    let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
    guard status == errSecSuccess else {
      throw SecureChannelError.authenticationFailed(
        "the system random number generator failed with status \(status)"
      )
    }
    return bytes
  }
}

private func constantTimeEquals(_ a: [UInt8], _ b: [UInt8]) -> Bool {
  guard a.count == b.count else { return false }
  var difference: UInt8 = 0
  for (x, y) in zip(a, b) { difference |= x ^ y }
  return difference == 0
}
