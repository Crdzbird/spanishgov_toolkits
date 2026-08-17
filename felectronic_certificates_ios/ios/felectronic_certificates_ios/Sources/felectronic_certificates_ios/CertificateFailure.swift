import Foundation
import Security

/// Failures the Keychain layer can produce.
///
/// Each case carries the stable wire ``code`` that Dart's
/// `CertificateError.fromPlatformException` switches on. Previously these
/// were `NSError`s whose *localized description* doubled as the error code,
/// so the plugin recovered the failure kind with
/// `switch error.localizedDescription { case "IncorrectPassword": ... }`.
/// That is fragile — `localizedDescription` is a presentation string, it can
/// be localized by the system, and a reworded message silently became
/// `UnknownError` on the Dart side.
///
/// - Important: ``code`` is a wire contract shared with Android and consumed
///   by `CertificateError`. Changing a value is a breaking change; adding a
///   case means adding the matching `CertificateError` subtype in Dart, or
///   it degrades to `CertUnknownError`.
enum CertificateFailure: Error {
    /// The PKCS#12 passphrase was wrong.
    case incorrectPassword

    /// An identity for this certificate is already in the Keychain.
    case alreadyExists

    /// No certificate matched the requested serial number.
    case notFound

    /// `SecPKCS12Import` failed for a reason other than a bad passphrase.
    case importFailed(OSStatus)

    /// The identity could not be written to the Keychain.
    case storeFailed(OSStatus)

    /// The identity could not be removed from the Keychain.
    case deleteFailed(OSStatus)

    /// The private key was unavailable, or `SecKeyCreateSignature` failed.
    case signingFailed(reason: String)

    /// Stable code consumed by `CertificateError.fromPlatformException`.
    var code: String {
        switch self {
        case .incorrectPassword:
            return "IncorrectPassword"
        case .alreadyExists:
            return "CertificateInKeyChain"
        case .notFound:
            return "CertificateNotFound"
        case .signingFailed:
            return "SigningError"
        case .importFailed, .storeFailed, .deleteFailed:
            return "UnknownError"
        }
    }

    /// Diagnostic text for this failure.
    ///
    /// Carries only `OSStatus` values and Security framework text — never a
    /// certificate's subject, serial, DER bytes or the PKCS#12 passphrase,
    /// since this string crosses to Dart and may be logged by the host app.
    var message: String {
        switch self {
        case .incorrectPassword:
            return "Incorrect PKCS#12 password"
        case .alreadyExists:
            return "Certificate already present in the Keychain"
        case .notFound:
            return "Certificate not found in the Keychain"
        case .importFailed(let status):
            return "Failed to import PKCS#12 (OSStatus \(status))"
        case .storeFailed(let status):
            return "Failed to store identity (OSStatus \(status))"
        case .deleteFailed(let status):
            return "Failed to delete identity (OSStatus \(status))"
        case .signingFailed(let reason):
            return reason
        }
    }
}
