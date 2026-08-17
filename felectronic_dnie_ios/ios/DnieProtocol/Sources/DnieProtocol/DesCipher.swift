import CommonCrypto
import Foundation

/// Errors raised by the DES primitives.
public enum DesError: Error, Equatable, Sendable {
  case badKeyLength(expected: String, actual: Int)
  case notBlockAligned(count: Int)
  case cryptoFailure(status: Int32)
}

/// Single DES, one block at a time.
///
/// Used only to build the retail MAC, where the CBC chaining is done by hand
/// so it can be read against the Java line by line. DES is a protocol
/// requirement of CWA-14890, not a choice: a 56-bit block cipher would never
/// be selected for anything new.
public enum Des {
  public static let blockSize = 8
  public static let keySize = 8

  /// Encrypts exactly one 8-byte block under an 8-byte key.
  public static func encryptBlock(_ block: [UInt8], key: [UInt8]) throws -> [UInt8] {
    guard key.count == keySize else {
      throw DesError.badKeyLength(expected: "\(keySize)", actual: key.count)
    }
    guard block.count == blockSize else {
      throw DesError.notBlockAligned(count: block.count)
    }
    return try crypt(
      block, key: key, algorithm: CCAlgorithm(kCCAlgorithmDES),
      operation: CCOperation(kCCEncrypt), options: CCOptions(kCCOptionECBMode)
    )
  }
}

/// Triple DES in CBC mode with an all-zero IV.
///
/// ## Why a zero IV
///
/// `BcCryptoHelper` builds its DESede cipher as a `CBCBlockCipher` but
/// initialises it with a bare `KeyParameter` rather than a `ParametersWithIV`.
/// BouncyCastle defaults the IV to zeros in that case, so the channel runs
/// CBC from a fixed all-zero IV. That is what the card expects and what the
/// working Android build sends.
///
/// A fixed IV is normally a real weakness — identical plaintexts encrypt
/// identically. Here each APDU's plaintext is prefixed by material that varies
/// per exchange and the session keys are fresh per channel, so the practical
/// exposure is limited; but the property is worth stating rather than leaving
/// for someone to discover. It is fixed by the protocol and cannot be changed
/// unilaterally.
public enum TripleDes {
  public static let blockSize = 8

  /// Expands a 16-byte two-key value to the 24-byte `K1‖K2‖K1` form.
  ///
  /// The session keys from `Cwa14890KeyDerivation` are 16 bytes. Two-key
  /// Triple DES is defined as `E_K1(D_K2(E_K1(x)))`, which is the three-key
  /// algorithm with `K3 = K1`; CommonCrypto only accepts the 24-byte form, so
  /// the expansion is done here. A 24-byte input is passed through unchanged.
  public static func expandKey(_ key: [UInt8]) throws -> [UInt8] {
    switch key.count {
    case 24: return key
    case 16: return key + key.prefix(8)
    default: throw DesError.badKeyLength(expected: "16 or 24", actual: key.count)
    }
  }

  public static func encrypt(_ data: [UInt8], key: [UInt8]) throws -> [UInt8] {
    try process(data, key: key, operation: CCOperation(kCCEncrypt))
  }

  public static func decrypt(_ data: [UInt8], key: [UInt8]) throws -> [UInt8] {
    try process(data, key: key, operation: CCOperation(kCCDecrypt))
  }

  private static func process(
    _ data: [UInt8], key: [UInt8], operation: CCOperation
  ) throws -> [UInt8] {
    guard data.count % blockSize == 0 else {
      throw DesError.notBlockAligned(count: data.count)
    }
    // A nil IV means all zeros to CommonCrypto, matching BouncyCastle's
    // behaviour with a bare KeyParameter. No padding: the caller has already
    // applied ISO 7816-4 padding, and letting CommonCrypto add PKCS#7 on top
    // would corrupt the message.
    return try crypt(
      data, key: try expandKey(key), algorithm: CCAlgorithm(kCCAlgorithm3DES),
      operation: operation, options: 0
    )
  }
}

// MARK: - CommonCrypto bridge

private func crypt(
  _ data: [UInt8], key: [UInt8], algorithm: CCAlgorithm,
  operation: CCOperation, options: CCOptions
) throws -> [UInt8] {
  guard !data.isEmpty else { return [] }
  var output = [UInt8](repeating: 0, count: data.count)
  var moved = 0

  let status = key.withUnsafeBytes { keyBytes in
    data.withUnsafeBytes { dataBytes in
      output.withUnsafeMutableBytes { outputBytes in
        CCCrypt(
          operation, algorithm, options,
          keyBytes.baseAddress, key.count,
          nil,  // zero IV
          dataBytes.baseAddress, data.count,
          outputBytes.baseAddress, outputBytes.count,
          &moved
        )
      }
    }
  }

  guard status == kCCSuccess else { throw DesError.cryptoFailure(status: status) }
  return Array(output.prefix(moved))
}
