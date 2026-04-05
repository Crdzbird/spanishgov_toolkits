import Flutter
import Foundation

/// iOS implementation of the felectronic_certificates plugin.
///
/// Uses ``KeychainCertificateManager`` for all Keychain operations
/// and stores the default certificate selection in ``UserDefaults``.
public class FelectronicCertificatesPlugin: NSObject, FlutterPlugin, FelectronicCertificatesHostApi {

    private let manager = KeychainCertificateManager()

    private static let defaultSerialKey = "felectronic_certificates_default_serial"

    private let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd-MM-yyyy"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt
    }()

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

        let identities = manager.getAllIdentities()
        for (identity, attrs) in identities {
            if let info = manager.getCertificateInfo(identity: identity),
               info.serialNumber == serial {
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
        algorithm: String,
        completion: @escaping (Result<FlutterStandardTypedData, any Error>) -> Void
    ) {
        guard let serial = UserDefaults.standard.string(
            forKey: FelectronicCertificatesPlugin.defaultSerialKey
        ) else {
            completion(.failure(FlutterError(
                code: "NotSelectedCertificate",
                message: "No default certificate selected",
                details: nil
            )))
            return
        }

        let identities = manager.getAllIdentities()
        for (identity, _) in identities {
            if let info = manager.getCertificateInfo(identity: identity),
               info.serialNumber == serial {
                do {
                    let signature = try manager.sign(
                        data: data.data,
                        algorithm: algorithm,
                        identity: identity
                    )
                    completion(.success(FlutterStandardTypedData(bytes: signature)))
                } catch {
                    completion(.failure(FlutterError(
                        code: "SigningError",
                        message: error.localizedDescription,
                        details: nil
                    )))
                }
                return
            }
        }

        completion(.failure(FlutterError(
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
        } catch let error as NSError {
            let code: String
            switch error.localizedDescription {
            case "IncorrectPassword":
                code = "IncorrectPassword"
            case "CertificateInKeyChain":
                code = "CertificateInKeyChain"
            default:
                code = "UnknownError"
            }
            completion(.failure(FlutterError(
                code: code,
                message: error.localizedDescription,
                details: nil
            )))
        }
    }

    func deleteDefaultCertificate(completion: @escaping (Result<Void, any Error>) -> Void) {
        guard let serial = UserDefaults.standard.string(
            forKey: FelectronicCertificatesPlugin.defaultSerialKey
        ) else {
            completion(.failure(FlutterError(
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
            completion(.failure(FlutterError(
                code: "CertificateNotFound",
                message: error.localizedDescription,
                details: nil
            )))
        }
    }

    func deleteCertificateBySerialNumber(
        serialNumber: String,
        completion: @escaping (Result<Void, any Error>) -> Void
    ) {
        do {
            try manager.deleteIdentity(serialNumber: serialNumber)
            // Clear default if it was the deleted certificate
            if UserDefaults.standard.string(
                forKey: FelectronicCertificatesPlugin.defaultSerialKey
            ) == serialNumber {
                UserDefaults.standard.removeObject(
                    forKey: FelectronicCertificatesPlugin.defaultSerialKey
                )
            }
            completion(.success(()))
        } catch let error as NSError {
            let code = error.localizedDescription == "CertificateNotFound"
                ? "CertificateNotFound"
                : "UnknownError"
            completion(.failure(FlutterError(
                code: code,
                message: error.localizedDescription,
                details: nil
            )))
        }
    }

    // MARK: - Helpers

    private func mapToMessage(
        info: CertificateInfo,
        attrs: [String: Any]
    ) -> DeviceCertificateMessage {
        let alias = attrs[kSecAttrLabel as String] as? String
        let usagesStr = info.usages.joined(separator: ";")
        let expStr = dateFormatter.string(from: info.expirationDate)

        return DeviceCertificateMessage(
            serialNumber: info.serialNumber,
            alias: alias,
            holderName: info.holderName,
            issuerName: info.issuerName,
            expirationDate: expStr,
            usages: usagesStr,
            encoded: FlutterStandardTypedData(bytes: info.encoded)
        )
    }
}
