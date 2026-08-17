import CryptoKit
import Foundation

/// CWA-14890 session key derivation.
///
/// After the mutual authentication exchange, both sides hold a shared 32-byte
/// seed (`Kifd XOR Kicc`). Two session keys are derived from it by hashing the
/// seed with a one-word counter appended: counter 1 yields the encryption key,
/// counter 2 the MAC key. Each key is the **first 16 bytes** of the SHA-1
/// digest; the remaining 4 digest bytes are discarded.
///
/// Transcribed from `Cwa14890OneV1Connection.generateKenc` / `generateKmac`:
///
/// ```objc
/// IOSByteArray *kidficcConcat = concatenateByteArrays(kidficc, SECURE_CHANNEL_KENC_AUX);
/// IOSByteArray *keyEnc = [IOSByteArray arrayWithLength:16];
/// arraycopy([cryptoHelper digest:SHA1 withByteArray:kidficcConcat], 0, keyEnc, 0, 16);
/// ```
///
/// with `SECURE_CHANNEL_KENC_AUX = 00 00 00 01` and
/// `SECURE_CHANNEL_KMAC_AUX = 00 00 00 02`, both read from the transpiled
/// class initialiser.
///
/// ## On SHA-1
///
/// SHA-1 is used because CWA-14890 specifies it; this is a protocol constant,
/// not a choice. It cannot be substituted without breaking interoperability
/// with the card. `CryptoKit.Insecure.SHA1` is the correct API and its name
/// accurately reflects that SHA-1 is unfit for new designs.
///
/// ## Verification status
///
/// The derivation is a pure function and is tested against SHA-1 vectors
/// computed independently of this code. What is **not** verified here is that
/// the seed fed in is the one a real DNIe agrees on — that depends on the
/// authentication exchange, which needs physical hardware.
public enum Cwa14890KeyDerivation {

  /// Counter appended to the seed when deriving the encryption key.
  public static let encryptionCounter: [UInt8] = [0x00, 0x00, 0x00, 0x01]

  /// Counter appended to the seed when deriving the MAC key.
  public static let macCounter: [UInt8] = [0x00, 0x00, 0x00, 0x02]

  /// Length of both derived keys, in bytes. A 16-byte key is used as a
  /// two-key Triple DES key (K1‖K2, with K3 = K1).
  public static let keyLength = 16

  /// Derives the session encryption key, `Kenc`.
  public static func encryptionKey(seed: [UInt8]) -> [UInt8] {
    derive(seed: seed, counter: encryptionCounter)
  }

  /// Derives the session MAC key, `Kmac`.
  public static func macKey(seed: [UInt8]) -> [UInt8] {
    derive(seed: seed, counter: macCounter)
  }

  /// `SHA1(seed ‖ counter)` truncated to 16 bytes.
  static func derive(seed: [UInt8], counter: [UInt8]) -> [UInt8] {
    var hasher = Insecure.SHA1()
    hasher.update(data: seed)
    hasher.update(data: counter)
    return Array(hasher.finalize().prefix(keyLength))
  }
}
