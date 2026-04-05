import Foundation
import Security

/// Encapsulates all Keychain operations for certificate management.
///
/// Reimplemented from the Portafirmas iOS production app using modern
/// Swift and Security.framework APIs.
class KeychainCertificateManager {

    // MARK: - Import

    /// Imports a PKCS#12 file into the Keychain.
    ///
    /// If a certificate with the same identity already exists,
    /// it is replaced silently (matching Portafirmas behavior).
    ///
    /// - Parameters:
    ///   - data: The raw PKCS#12 bytes.
    ///   - password: The password protecting the .p12 file.
    ///   - alias: An optional label to assign to the imported identity.
    /// - Throws: NSError with appropriate localized description on failure.
    func importPKCS12(data: Data, password: String?, alias: String?) throws {
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: password ?? ""
        ]

        var items: CFArray?
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)

        guard status == errSecSuccess,
              let importedItems = items as? [[String: Any]],
              let firstItem = importedItems.first,
              let identity = firstItem[kSecImportItemIdentity as String]
        else {
            if status == errSecAuthFailed || status == -25293 {
                throw NSError(
                    domain: "FelectronicCertificates",
                    code: Int(status),
                    userInfo: [NSLocalizedDescriptionKey: "IncorrectPassword"]
                )
            }
            throw NSError(
                domain: "FelectronicCertificates",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Failed to import PKCS#12"]
            )
        }

        // Remove existing identity first (Portafirmas pattern: replace silently)
        var deleteQuery: [String: Any] = [
            kSecValueRef as String: identity,
        ]
        addAccessGroup(to: &deleteQuery)
        SecItemDelete(deleteQuery as CFDictionary)

        // Store identity in Keychain
        var addQuery: [String: Any] = [
            kSecValueRef as String: identity,
        ]
        addAccessGroup(to: &addQuery)

        if let alias = alias, !alias.isEmpty {
            addQuery[kSecAttrLabel as String] = alias
        }

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        if addStatus == errSecDuplicateItem || addStatus == -25299 {
            throw NSError(
                domain: "FelectronicCertificates",
                code: Int(addStatus),
                userInfo: [NSLocalizedDescriptionKey: "CertificateInKeyChain"]
            )
        }

        guard addStatus == errSecSuccess else {
            throw NSError(
                domain: "FelectronicCertificates",
                code: Int(addStatus),
                userInfo: [NSLocalizedDescriptionKey: "Failed to store identity (\(addStatus))"]
            )
        }
    }

    // MARK: - Query

    /// Returns all identities stored in the Keychain.
    func getAllIdentities() -> [(SecIdentity, [String: Any])] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnRef as String: true,
            kSecReturnAttributes as String: true,
        ]
        addAccessGroup(to: &query)

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]]
        else {
            return []
        }

        return items.compactMap { attrs in
            guard let ref = attrs[kSecValueRef as String] else { return nil }
            // swiftlint:disable:next force_cast
            return (ref as! SecIdentity, attrs)
        }
    }

    /// Searches for a specific identity by its label (alias).
    func findIdentityByLabel(_ label: String) -> (SecIdentity, [String: Any])? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: label,
            kSecReturnRef as String: true,
            kSecReturnAttributes as String: true,
        ]
        addAccessGroup(to: &query)

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let attrs = result as? [String: Any],
              let ref = attrs[kSecValueRef as String]
        else {
            return nil
        }

        // swiftlint:disable:next force_cast
        return (ref as! SecIdentity, attrs)
    }

    /// Extracts certificate info from a SecIdentity.
    func getCertificateInfo(identity: SecIdentity) -> CertificateInfo? {
        var certificate: SecCertificate?
        let status = SecIdentityCopyCertificate(identity, &certificate)
        guard status == errSecSuccess, let cert = certificate else { return nil }

        let summary = SecCertificateCopySubjectSummary(cert) as String? ?? ""
        let derData = SecCertificateCopyData(cert) as Data

        // Serial number
        var serialError: Unmanaged<CFError>?
        let serialData = SecCertificateCopySerialNumberData(cert, &serialError)
        let serialHex = (serialData as Data?)?
            .map { String(format: "%02x", $0) }
            .joined() ?? ""

        // Parse certificate fields
        var issuerName = ""
        var expirationDate = Date()
        var creationDate = Date()
        var usages: [String] = []

        if let values = SecCertificateCopyValues(cert, nil, nil) as? [String: Any] {
            // Not Valid After — try multiple keys (OID and display name)
            expirationDate = extractDate(
                from: values,
                keys: [
                    "2.16.840.1.113741.2.1.1.1.4", // Intel OID
                    "Not Valid After",
                ]
            ) ?? Date()

            // Not Valid Before
            creationDate = extractDate(
                from: values,
                keys: [
                    "2.16.840.1.113741.2.1.1.1.3",
                    "Not Valid Before",
                ]
            ) ?? Date()

            // Issuer Name — extract CN from structured issuer data
            issuerName = extractIssuerCN(from: values)

            // Key Usage (OID 2.5.29.15)
            usages = extractKeyUsages(from: values)
        }

        // Extract public key DER for server-side validation
        var publicKeyData: Data?
        if let trust = createTrust(for: cert) {
            if let pubKey = SecTrustCopyKey(trust) {
                var pubKeyError: Unmanaged<CFError>?
                if let keyData = SecKeyCopyExternalRepresentation(pubKey, &pubKeyError) {
                    publicKeyData = keyData as Data
                }
            }
        }

        return CertificateInfo(
            serialNumber: serialHex,
            alias: nil,
            holderName: summary,
            issuerName: issuerName,
            expirationDate: expirationDate,
            creationDate: creationDate,
            usages: Array(Set(usages)),
            encoded: derData,
            publicKeyData: publicKeyData
        )
    }

    // MARK: - Delete

    /// Deletes an identity from the Keychain by serial number.
    func deleteIdentity(serialNumber: String) throws {
        let identities = getAllIdentities()
        for (identity, _) in identities {
            if let info = getCertificateInfo(identity: identity),
               info.serialNumber == serialNumber {

                var deleteQuery: [String: Any] = [
                    kSecClass as String: kSecClassIdentity,
                    kSecValueRef as String: identity,
                ]
                addAccessGroup(to: &deleteQuery)

                let status = SecItemDelete(deleteQuery as CFDictionary)
                guard status == errSecSuccess else {
                    throw NSError(
                        domain: "FelectronicCertificates",
                        code: Int(status),
                        userInfo: [NSLocalizedDescriptionKey: "Failed to delete identity"]
                    )
                }

                // Also delete the associated certificate
                var certDeleteQuery: [String: Any] = [
                    kSecClass as String: kSecClassCertificate,
                    kSecMatchLimit as String: kSecMatchLimitAll,
                    kSecReturnRef as String: true,
                ]
                addAccessGroup(to: &certDeleteQuery)
                // Best-effort certificate cleanup
                SecItemDelete(certDeleteQuery as CFDictionary)

                return
            }
        }
        throw NSError(
            domain: "FelectronicCertificates",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "CertificateNotFound"]
        )
    }

    // MARK: - Sign

    /// Signs data using the private key of the given identity.
    func sign(
        data: Data,
        algorithm: String,
        identity: SecIdentity
    ) throws -> Data {
        var privateKey: SecKey?
        let status = SecIdentityCopyPrivateKey(identity, &privateKey)
        guard status == errSecSuccess, let key = privateKey else {
            throw NSError(
                domain: "FelectronicCertificates",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "SigningError"]
            )
        }

        let secAlgorithm = mapAlgorithm(algorithm)

        var signError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            key,
            secAlgorithm,
            data as CFData,
            &signError
        ) else {
            let errorDesc = signError?.takeRetainedValue().localizedDescription
                ?? "Signing failed"
            throw NSError(
                domain: "FelectronicCertificates",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: errorDesc]
            )
        }

        return signature as Data
    }

    // MARK: - Trust Validation

    /// Validates the trust chain for a certificate.
    func validateTrust(for identity: SecIdentity) -> Bool {
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
              let cert = certificate,
              let trust = createTrust(for: cert)
        else {
            return false
        }

        var error: CFError?
        return SecTrustEvaluateWithError(trust, &error)
    }

    // MARK: - Private Helpers

    private func createTrust(for certificate: SecCertificate) -> SecTrust? {
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(
            certificate,
            policy,
            &trust
        )
        return status == errSecSuccess ? trust : nil
    }

    private func extractDate(
        from values: [String: Any],
        keys: [String]
    ) -> Date? {
        for key in keys {
            if let entry = values[key] as? [String: Any],
               let dateValue = entry[kSecPropertyKeyValue as String] as? Date {
                return dateValue
            }
        }
        return nil
    }

    private func extractIssuerCN(from values: [String: Any]) -> String {
        // Try structured "Issuer Name" key
        if let issuer = values["Issuer Name"] as? [String: Any],
           let issuerFields = issuer[kSecPropertyKeyValue as String] as? [[String: Any]] {
            for field in issuerFields {
                if let label = field[kSecPropertyKeyLabel as String] as? String,
                   label == "2.5.4.3",
                   let value = field[kSecPropertyKeyValue as String] as? String {
                    return value
                }
            }
        }

        // Try OID-based issuer CN
        if let issuerCN = values["2.5.4.3"] as? [String: Any],
           let value = issuerCN["value"] as? String {
            return value
        }

        return ""
    }

    private func extractKeyUsages(from values: [String: Any]) -> [String] {
        var usages: [String] = []

        if let keyUsage = values["2.5.29.15"] as? [String: Any],
           let usageValue = keyUsage[kSecPropertyKeyValue as String] {
            if let usageNumber = usageValue as? Int {
                // Bit 0 (0x80): digitalSignature → AUTHENTICATION
                if usageNumber & 0x80 != 0 { usages.append("AUTHENTICATION") }
                // Bit 1 (0x40): nonRepudiation → SIGNING
                if usageNumber & 0x40 != 0 { usages.append("SIGNING") }
                // Bit 2 (0x20): keyEncipherment → ENCRYPTION
                if usageNumber & 0x20 != 0 { usages.append("ENCRYPTION") }
                // Bit 3 (0x10): dataEncipherment → ENCRYPTION
                if usageNumber & 0x10 != 0 { usages.append("ENCRYPTION") }
            }
        }

        // If no key usage extension found, assume signing + authentication
        if usages.isEmpty {
            usages = ["SIGNING", "AUTHENTICATION"]
        }

        return usages
    }

    private func mapAlgorithm(_ algorithm: String) -> SecKeyAlgorithm {
        switch algorithm.uppercased() {
        case "SHA256RSA":
            return .rsaSignatureMessagePKCS1v15SHA256
        case "SHA384RSA":
            return .rsaSignatureMessagePKCS1v15SHA384
        case "SHA512RSA":
            return .rsaSignatureMessagePKCS1v15SHA512
        case "SHA256EC":
            return .ecdsaSignatureMessageX962SHA256
        case "SHA384EC":
            return .ecdsaSignatureMessageX962SHA384
        case "SHA512EC":
            return .ecdsaSignatureMessageX962SHA512
        default:
            return .rsaSignatureMessagePKCS1v15SHA256
        }
    }

    /// Adds the Keychain access group for multi-app scenarios.
    /// Skipped on simulator where access groups aren't available.
    private func addAccessGroup(to query: inout [String: Any]) {
        #if !targetEnvironment(simulator)
        if let group = Self.accessGroup() {
            query[kSecAttrAccessGroup as String] = group
        }
        #endif
    }

    /// Retrieves the app's Keychain access group.
    private static func accessGroup() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "bundleSeedID",
            kSecAttrService as String: "",
            kSecReturnAttributes as String: true,
        ]

        var result: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            status = SecItemAdd(query as CFDictionary, &result)
        }

        guard status == errSecSuccess,
              let attrs = result as? [String: Any],
              let group = attrs[kSecAttrAccessGroup as String] as? String
        else {
            return nil
        }

        return group
    }
}

/// Lightweight struct for passing certificate info within Swift.
struct CertificateInfo {
    let serialNumber: String
    let alias: String?
    let holderName: String
    let issuerName: String
    let expirationDate: Date
    let creationDate: Date
    let usages: [String]
    let encoded: Data
    let publicKeyData: Data?
}
