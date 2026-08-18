import Flutter
import Foundation
import Security

extension CertSignAlgorithmMessage {
    /// The Security framework algorithm for this wire value.
    ///
    /// Exhaustive with no `default` branch: adding a case to the Pigeon
    /// schema becomes a compile error here instead of silently falling back
    /// to SHA-256/RSA, which previously meant an EC algorithm could be signed
    /// with RSA parameters and fail with an opaque Security error.
    var secKeyAlgorithm: SecKeyAlgorithm {
        switch self {
        case .sha256rsa: return .rsaSignatureMessagePKCS1v15SHA256
        case .sha384rsa: return .rsaSignatureMessagePKCS1v15SHA384
        case .sha512rsa: return .rsaSignatureMessagePKCS1v15SHA512
        case .sha256ec: return .ecdsaSignatureMessageX962SHA256
        case .sha384ec: return .ecdsaSignatureMessageX962SHA384
        case .sha512ec: return .ecdsaSignatureMessageX962SHA512
        }
    }
}

/// iOS implementation of the felectronic_certificates plugin.
///
/// Uses ``KeychainCertificateManager`` for all Keychain operations
/// and stores the default certificate selection in ``UserDefaults``.
public class FelectronicCertificatesPlugin: NSObject, FlutterPlugin, FelectronicCertificatesHostApi {

    private let manager = KeychainCertificateManager()

    private static let defaultSerialKey = "felectronic_certificates_default_serial"

    // MARK: - FlutterPlugin

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FelectronicCertificatesPlugin()
        FelectronicCertificatesHostApiSetup.setUp(
            binaryMessenger: registrar.messenger(),
            api: instance
        )
    }

    // MARK: - FelectronicCertificatesHostApi

    func getAllCertificates(completion: @escaping (Result<[DeviceCertificateMessage?], any Error>) -> Void) {
        let identities = manager.getAllIdentities()
        let messages: [DeviceCertificateMessage?] = identities.compactMap { identity, attrs in
            guard let info = manager.getCertificateInfo(identity: identity) else { return nil }
            return mapToMessage(info: info, attrs: attrs)
        }
        completion(.success(messages))
    }

    func getDefaultCertificate(completion: @escaping (Result<DeviceCertificateMessage?, any Error>) -> Void) {
        guard let serial = UserDefaults.standard.string(
            forKey: FelectronicCertificatesPlugin.defaultSerialKey
        ) else {
            completion(.success(nil))
            return
        }

        // Serials persisted by earlier versions used the DER spelling
        // (with the sign-pad byte), so compare canonically.
        let wanted = KeychainCertificateManager.canonicalSerial(serial)
        let identities = manager.getAllIdentities()
        for (identity, attrs) in identities {
            if let info = manager.getCertificateInfo(identity: identity),
               info.serialNumber == wanted {
                completion(.success(mapToMessage(info: info, attrs: attrs)))
                return
            }
        }
        completion(.success(nil))
    }

    func selectDefaultCertificate(completion: @escaping (Result<DeviceCertificateMessage?, any Error>) -> Void) {
        // iOS does not have a built-in certificate picker like Android.
        // Return all available identities. If only one exists, auto-select it.
        // If multiple exist, select the first one (Dart layer can present
        // a custom picker using getAllCertificates + setDefaultCertificateBySerialNumber).
        let identities = manager.getAllIdentities()
        guard let (identity, attrs) = identities.first,
              let info = manager.getCertificateInfo(identity: identity)
        else {
            completion(.success(nil))
            return
        }

        UserDefaults.standard.set(
            info.serialNumber,
            forKey: FelectronicCertificatesPlugin.defaultSerialKey
        )
        completion(.success(mapToMessage(info: info, attrs: attrs)))
    }

    func setDefaultCertificateBySerialNumber(
        serialNumber: String,
        completion: @escaping (Result<Void, any Error>) -> Void
    ) {
        UserDefaults.standard.set(
            serialNumber,
            forKey: FelectronicCertificatesPlugin.defaultSerialKey
        )
        completion(.success(()))
    }

    func clearDefaultCertificate(completion: @escaping (Result<Void, any Error>) -> Void) {
        UserDefaults.standard.removeObject(
            forKey: FelectronicCertificatesPlugin.defaultSerialKey
        )
        completion(.success(()))
    }

    func signWithDefaultCertificate(
        data: FlutterStandardTypedData,
        algorithm: CertSignAlgorithmMessage,
        completion: @escaping (Result<FlutterStandardTypedData, any Error>) -> Void
    ) {
        guard let serial = UserDefaults.standard.string(
            forKey: FelectronicCertificatesPlugin.defaultSerialKey
        ) else {
            completion(.failure(PigeonError(
                code: "NotSelectedCertificate",
                message: "No default certificate selected",
                details: nil
            )))
            return
        }

        let wanted = KeychainCertificateManager.canonicalSerial(serial)
        let identities = manager.getAllIdentities()
        for (identity, _) in identities {
            if let info = manager.getCertificateInfo(identity: identity),
               info.serialNumber == wanted {
                do {
                    let signature = try manager.sign(
                        data: data.data,
                        algorithm: algorithm.secKeyAlgorithm,
                        identity: identity
                    )
                    completion(.success(
                        FlutterStandardTypedData(bytes: signature)
                    ))
                } catch {
                    completion(.failure(Self.pigeonError(from: error)))
                }
                return
            }
        }

        completion(.failure(PigeonError(
            code: "CertificateNotFound",
            message: "Default certificate not found in Keychain",
            details: nil
        )))
    }

    func importCertificate(
        pkcs12Data: FlutterStandardTypedData,
        password: String?,
        alias: String?,
        completion: @escaping (Result<Void, any Error>) -> Void
    ) {
        do {
            try manager.importPKCS12(
                data: pkcs12Data.data,
                password: password,
                alias: alias
            )
            completion(.success(()))
        } catch {
            completion(.failure(Self.pigeonError(from: error)))
        }
    }

    func deleteDefaultCertificate(
        completion: @escaping (Result<Void, any Error>) -> Void
    ) {
        guard let serial = UserDefaults.standard.string(
            forKey: FelectronicCertificatesPlugin.defaultSerialKey
        ) else {
            completion(.failure(PigeonError(
                code: "NotSelectedCertificate",
                message: "No default certificate selected",
                details: nil
            )))
            return
        }

        do {
            try manager.deleteIdentity(serialNumber: serial)
            UserDefaults.standard.removeObject(
                forKey: FelectronicCertificatesPlugin.defaultSerialKey
            )
            completion(.success(()))
        } catch {
            completion(.failure(Self.pigeonError(from: error)))
        }
    }

    func deleteCertificateBySerialNumber(
        serialNumber: String,
        completion: @escaping (Result<Void, any Error>) -> Void
    ) {
        do {
            try manager.deleteIdentity(serialNumber: serialNumber)
            // Clear default if it was the deleted certificate
            let storedDefault = UserDefaults.standard.string(
                forKey: FelectronicCertificatesPlugin.defaultSerialKey
            )
            if let stored = storedDefault,
               KeychainCertificateManager.canonicalSerial(stored)
                   == KeychainCertificateManager.canonicalSerial(serialNumber) {
                UserDefaults.standard.removeObject(
                    forKey: FelectronicCertificatesPlugin.defaultSerialKey
                )
            }
            completion(.success(()))
        } catch {
            completion(.failure(Self.pigeonError(from: error)))
        }
    }

    // MARK: - Helpers

    /// Translates a Swift error into the Pigeon error Dart maps to a
    /// ``CertificateError``.
    ///
    /// ``CertificateFailure`` carries its own stable wire code; anything else
    /// is reported as `UnknownError` rather than being guessed at from a
    /// display string.
    private static func pigeonError(from error: Error) -> PigeonError {
        if let failure = error as? CertificateFailure {
            return PigeonError(
                code: failure.code,
                message: failure.message,
                details: nil
            )
        }
        return PigeonError(
            code: "UnknownError",
            message: error.localizedDescription,
            details: nil
        )
    }


    /// Builds the Pigeon message from the natively-sourced facts.
    ///
    /// Only the serial, the Keychain label and the DER cross the boundary.
    /// Dart decodes everything else from `encoded` via `felectronic_x509`.
    private func mapToMessage(
        info: CertificateInfo,
        attrs: [String: Any]
    ) -> DeviceCertificateMessage {
        return DeviceCertificateMessage(
            serialNumber: info.serialNumber,
            alias: attrs[kSecAttrLabel as String] as? String,
            encoded: FlutterStandardTypedData(bytes: info.encoded),
            chain: info.chain.isEmpty
                ? nil
                : info.chain.map { FlutterStandardTypedData(bytes: $0) }
        )
    }
}
