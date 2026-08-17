import Foundation

/// Framing and status-word handling for CWA-14890 secure messaging.
///
/// This type covers the parts of the secure channel that are pure byte
/// manipulation. The cryptography that fills the data field — Triple DES in
/// CBC mode for confidentiality, ISO 9797-1 retail MAC for integrity — is not
/// here yet; see the note at the bottom of this file.
public enum SecureMessaging {

  /// `0x8E`, the BER tag introducing a cryptographic checksum.
  ///
  /// The transpiled source stores it as the signed byte `-114`, which is the
  /// same value.
  public static let cryptographicChecksumTag: UInt8 = 0x8E

  /// Appends a cryptographic checksum data object to an already-built
  /// secure-messaging data field.
  ///
  /// From `Cwa14890CipheredApdu.buildData`:
  ///
  /// ```objc
  /// [baos writeWithByteArray:data];
  /// [baos writeWithInt:TAG_CRYPTOGRAPHIC_CHECKSUM];
  /// [baos writeWithInt:(jbyte) mac->size_];
  /// [baos writeWithByteArray:mac];
  /// ```
  ///
  /// The Java rejects any MAC that is not 4 or 8 bytes, and so does this. That
  /// check is worth keeping: a truncated MAC silently weakens the channel, and
  /// a length mismatch here would otherwise surface only as an opaque card
  /// rejection.
  public static func appendingChecksum(
    to data: [UInt8], mac: [UInt8]
  ) throws -> [UInt8] {
    guard mac.count == 4 || mac.count == 8 else {
      throw SecureChannelError.badChecksumLength(actual: mac.count)
    }
    return data + [cryptographicChecksumTag, UInt8(mac.count)] + mac
  }
}

// MARK: - Status words specific to the secure channel

public extension StatusWord {

  /// `66 88` — the card computed a different MAC than we sent.
  ///
  /// Unrecoverable in practice: it means the send sequence counter or the
  /// session keys have diverged from the card's, so every later command will
  /// fail the same way. The channel has to be torn down and re-established.
  static let invalidCryptographicChecksum = StatusWord(sw1: 0x66, sw2: 0x88)

  /// How a secure-messaging exchange should proceed after a response.
  enum SecureMessagingRetry: Equatable, Sendable {
    /// Deliver the response to the caller.
    case accept
    /// Resend the command with `Le` set to this value.
    case resend(le: Int)
    /// Resend the command with `Le` reduced by one.
    case resendWithOneLessByte
    /// Give up; the channel is broken.
    case fail(SecureChannelError)
  }

  /// Classifies a decrypted response, mirroring the retry ladder in
  /// `Cwa14890OneV1Connection.transmit`.
  ///
  /// Two distinct wrong-length signals are handled, and they are handled
  /// differently — a detail easy to get backwards:
  ///
  /// - `6C xx` (`MSB_INCORRECT_LE`) — the card states the correct length in
  ///   `xx`, so the command is resent asking for exactly that.
  /// - `62 xx` (`MSB_INCORRECT_LE_PACE`) — no usable length is offered, so the
  ///   Java retries with `Le - 1` and converges by stepping down.
  ///
  /// The caller owns the retry loop, and must bound it: `resendWithOneLessByte`
  /// walks `Le` downward one byte at a time and nothing in the protocol
  /// guarantees it terminates.
  ///
  /// ## Divergence from `wrongLe`
  ///
  /// `StatusWord.wrongLe` reads `6C 00` as 256, following the ISO 7816-4
  /// convention that a zero length field means the maximum. This property
  /// instead returns the raw `0`, because the Java passes `getLsb()` straight
  /// into `setLe` with no such mapping. The two are deliberately not unified:
  /// `wrongLe` describes what the standard means, this describes what the
  /// working Android build actually sends. Reconciling them is a question for
  /// a real card, not for a reading of the spec.
  var secureMessagingOutcome: SecureMessagingRetry {
    if self == .invalidCryptographicChecksum {
      return .fail(.invalidCryptographicChecksum)
    }
    switch sw1 {
    case 0x6C: return .resend(le: Int(sw2))
    case 0x62: return .resendWithOneLessByte
    default: return .accept
    }
  }
}

// MARK: - Not yet implemented
//
// `AbstractApduEncrypter.protectAPDU` and `decryptResponseApdu` remain to be
// ported. They need Triple DES in CBC mode and an ISO 9797-1 Algorithm 3
// retail MAC, both reachable through CommonCrypto. Until those exist there is
// no working secure channel — the pieces in this file are its framing, not the
// channel itself.
