import Foundation

/// Maps iOS `NFCError` cases to the same error codes used on Android,
/// ensuring consistent `FlutterError` codes across both platforms.
extension NFCError {

    /// The error code sent to Dart via `FlutterError.code`.
    /// These match the Android `DNIeSignerException` class names.
    var flutterErrorCode: String {
        switch self {
        case .badPin:  // associated value not used for code
            return "DSDNIeWrongPINException"
        case .invalidCAnOrMrz:
            return "DSDNIeWrongCANException"
        case .burnedDNIeCard:
            return "DSDNIeDamagedException"
        case .invalidCard:
            return "DSNotDNIeException"
        case .authenticationModeLocked:
            return "DSDNIeLockedPINException"
        case .underAge:
            return "DSUnderageDocumentException"
        case .cardExpired, .certExpired:
            return "DSExpiredCertificateException"
        case .readTimeOut:
            return "DSTimeoutException"
        case .userCancelledSession:
            return "DSUserCancelledException"
        case .defectiveCard:
            return "DSDNIeDamagedException"
        case .noTag, .noTagSession:
            return "DSCardTagException"
        case .tagSendCommandFail:
            return "DSDNIeConnectionException"
        case .iso7816Fail, .notAvailable, .notAvailableForOSVersion:
            return "DSDNIeProviderException"
        case .noDataReaded:
            return "DSPrivateKeyException"
        case .requestalreadyExists, .cryptoCardException, .generic:
            return "DSUnknownException"
        }
    }

    /// The human-readable message sent to Dart via `FlutterError.message`.
    var flutterErrorMessage: String {
        switch self {
        case .badPin(let retries):
            return "Wrong PIN entered. \(retries) retries remaining."
        case .invalidCAnOrMrz:
            return "Wrong CAN entered."
        case .burnedDNIeCard:
            return "The DNIe appears to be damaged."
        case .invalidCard:
            return "The card is not a Spanish electronic DNIe."
        case .authenticationModeLocked:
            return "DNIe locked. Too many incorrect PIN attempts."
        case .underAge:
            return "Document belongs to an underage user."
        case .cardExpired:
            return "The DNIe card has expired."
        case .certExpired:
            return "The DNIe certificate has expired."
        case .readTimeOut:
            return "DNIe card detection timed out."
        case .userCancelledSession:
            return "NFC session cancelled by user."
        case .defectiveCard:
            return "The DNIe appears to be defective."
        case .noTag:
            return "No NFC tag detected."
        case .noTagSession:
            return "NFC tag session not available."
        case .tagSendCommandFail:
            return "Failed to send command to NFC tag."
        case .iso7816Fail:
            return "ISO 7816 communication failed."
        case .notAvailable:
            return "NFC is not available on this device."
        case .notAvailableForOSVersion:
            return "NFC requires iOS 15 or later."
        case .noDataReaded:
            return "No data could be read from the DNIe."
        case .requestalreadyExists:
            return "A signing request is already in progress."
        case .cryptoCardException:
            return "Cryptographic card exception."
        case .generic:
            return "An unknown NFC error occurred."
        }
    }
}
