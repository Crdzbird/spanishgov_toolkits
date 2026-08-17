import Foundation
import Security

/// Raw (textbook) RSA — modular exponentiation with no padding scheme.
///
/// CWA-14890 applies ISO 9796-2 itself, so the RSA layer beneath must not add
/// or check padding of its own. That makes this interface unsafe for any
/// general purpose: raw RSA is malleable and deterministic. It exists solely
/// to implement the card protocol, and nothing outside this module should use
/// it for anything else.
public protocol RsaRawCipher {
  /// Modulus length in bytes; every operation produces exactly this many.
  var modulusLength: Int { get }
  /// The modulus, big-endian — needed for the `min(sig, n - sig)` step.
  var modulus: [UInt8] { get }
  /// Applies the private exponent.
  func privateOperation(_ input: [UInt8]) throws -> [UInt8]
  /// Applies the public exponent.
  func publicOperation(_ input: [UInt8]) throws -> [UInt8]
}

public enum RsaError: Error, Equatable, Sendable {
  case inputTooLong(count: Int, modulusLength: Int)
  case operationFailed(String)
  case notAPrivateKey
}

// MARK: - Unsigned big-endian arithmetic
//
// The authentication exchange needs exactly two operations on numbers far
// wider than UInt64: compare, and subtract. A full bignum type would be more
// than the protocol asks for, so only those two are implemented.

enum BigEndian {

  /// Compares two big-endian unsigned values of any lengths.
  static func compare(_ a: [UInt8], _ b: [UInt8]) -> ComparisonResult {
    let x = stripLeadingZeros(a)
    let y = stripLeadingZeros(b)
    if x.count != y.count { return x.count < y.count ? .orderedAscending : .orderedDescending }
    for (i, j) in zip(x, y) where i != j {
      return i < j ? .orderedAscending : .orderedDescending
    }
    return .orderedSame
  }

  /// `a - b`, both big-endian unsigned, with `a >= b` required. The result is
  /// returned at `width` bytes, left-padded with zeros.
  static func subtract(_ a: [UInt8], _ b: [UInt8], width: Int) -> [UInt8] {
    var result = [UInt8](repeating: 0, count: width)
    var borrow = 0
    for i in 0..<width {
      let x = Int(a.count > i ? a[a.count - 1 - i] : 0)
      let y = Int(b.count > i ? b[b.count - 1 - i] : 0)
      var difference = x - y - borrow
      if difference < 0 {
        difference += 256
        borrow = 1
      } else {
        borrow = 0
      }
      result[width - 1 - i] = UInt8(difference)
    }
    return result
  }

  static func stripLeadingZeros(_ bytes: [UInt8]) -> [UInt8] {
    Array(bytes.drop { $0 == 0 })
  }

  /// Left-pads with zeros to exactly `width` bytes, or trims leading zeros
  /// when the input is longer — the normalisation `BigInteger.toByteArray()`
  /// forces on the Java side, where a sign byte may appear.
  static func normalize(_ bytes: [UInt8], to width: Int) -> [UInt8] {
    if bytes.count == width { return bytes }
    if bytes.count > width { return Array(bytes.suffix(width)) }
    return [UInt8](repeating: 0, count: width - bytes.count) + bytes
  }
}

// MARK: - Security framework implementation

/// `RsaRawCipher` backed by a `SecKey`.
///
/// Both directions use `kSecKeyAlgorithmRSAEncryptionRaw`, which is modular
/// exponentiation with no padding — the only mode that matches what the card
/// protocol expects.
public struct SecKeyRsaCipher: RsaRawCipher {
  public let modulusLength: Int
  public let modulus: [UInt8]
  private let privateKey: SecKey?
  private let publicKey: SecKey

  /// Wraps a key pair. `privateKey` may be omitted when only the public
  /// operation is needed, as it is for the card's key.
  public init(publicKey: SecKey, privateKey: SecKey? = nil) throws {
    self.publicKey = publicKey
    self.privateKey = privateKey
    self.modulusLength = SecKeyGetBlockSize(publicKey)

    guard let data = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
      throw RsaError.operationFailed("could not export the public key")
    }
    // PKCS#1 RSAPublicKey ::= SEQUENCE { modulus INTEGER, exponent INTEGER }
    guard let sequence = try? BerTlv.decode([UInt8](data)),
          let first = try? sequence.children().first
    else {
      throw RsaError.operationFailed("unexpected public key encoding")
    }
    self.modulus = BigEndian.stripLeadingZeros(first.value)
  }

  public func privateOperation(_ input: [UInt8]) throws -> [UInt8] {
    guard let privateKey else { throw RsaError.notAPrivateKey }
    return try transform(input, key: privateKey, encrypt: false)
  }

  public func publicOperation(_ input: [UInt8]) throws -> [UInt8] {
    try transform(input, key: publicKey, encrypt: true)
  }

  private func transform(_ input: [UInt8], key: SecKey, encrypt: Bool) throws -> [UInt8] {
    guard input.count <= modulusLength else {
      throw RsaError.inputTooLong(count: input.count, modulusLength: modulusLength)
    }
    // Raw RSA operates on exactly one modulus-wide block.
    let block = Data(BigEndian.normalize(input, to: modulusLength))

    var error: Unmanaged<CFError>?
    let output = encrypt
      ? SecKeyCreateEncryptedData(key, .rsaEncryptionRaw, block as CFData, &error)
      : SecKeyCreateDecryptedData(key, .rsaEncryptionRaw, block as CFData, &error)

    guard let output = output as Data? else {
      let message = (error?.takeRetainedValue()).map { String(describing: $0) } ?? "unknown"
      throw RsaError.operationFailed(message)
    }
    return BigEndian.normalize([UInt8](output), to: modulusLength)
  }
}
