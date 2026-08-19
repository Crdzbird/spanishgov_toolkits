import Foundation
import Security

/// Encapsulates all Keychain operations for certificate management.
///
/// Uses iOS-only Security framework APIs:
/// - `SecCertificateCopyData` for DER bytes
/// - `SecCertificateCopySerialNumberData` (iOS 11+) for the serial number
///
/// This layer deliberately does **not** decode the certificate. Every field
/// derivable from the DER encoding (issuer, subject CN, validity, key usage)
/// is parsed once in Dart by `felectronic_x509`, so iOS and Android cannot
/// drift apart. `SecCertificateCopyValues` is macOS-only and is not an
/// option here; hand-rolling an ASN.1 parser per platform was the
/// alternative, and duplicating a tested Dart parser in Swift is not worth
/// the maintenance or the bug surface.
///
/// - SeeAlso: `MethodChannelFelectronicCertificates._toCertificate` (Dart).
class KeychainCertificateManager {

    // MARK: - Import

    /// Imports a PKCS#12 file into the Keychain.
    ///
    /// ## Why this does not simply add the identity
    ///
    /// On iOS `SecPKCS12Import` **already inserts** the identity into the
    /// Keychain as a side effect. An earlier version of this method then
    /// deleted by identity reference and re-added, which had two consequences:
    /// the delete's status was discarded, and when it did not remove the item
    /// the following `SecItemAdd` returned `errSecDuplicateItem` — reported to
    /// the caller as "already exists" on a *first* import, which is both wrong
    /// and impossible to act on.
    ///
    /// So the import's own insert is treated as the primary path. The identity
    /// is read back afterwards, and the protection class and label are applied
    /// with `SecItemUpdate` rather than by re-adding. `SecItemAdd` is kept only
    /// as a fallback for a platform where the side-effect insert does not
    /// happen.
    ///
    /// Whether the certificate was *already* present is decided by comparing
    /// the Keychain before and after, not by interpreting an add failure.
    ///
    /// - Parameters:
    ///   - data: The raw PKCS#12 bytes.
    ///   - password: The password protecting the file, or nil when it has none.
    ///     Note that nil and `""` are different: an empty passphrase is a
    ///     passphrase.
    ///   - alias: An optional label to assign to the imported certificate.
    /// - Returns: The imported certificate, read back from the Keychain.
    /// - Throws: ``CertificateFailure``.
    @discardableResult
    func importPKCS12(
        data: Data,
        password: String?,
        alias: String?
    ) throws -> CertificateInfo {
        let existingSerials = Set(
            getAllIdentities().compactMap {
                getCertificateInfo(identity: $0.0)?.serialNumber
            }
        )

        var options: [String: Any] = [:]
        if let password {
            options[kSecImportExportPassphrase as String] = password
        }

        var items: CFArray?
        let status = SecPKCS12Import(
            data as CFData,
            options as CFDictionary,
            &items
        )
        guard status == errSecSuccess,
              let importedItems = items as? [[String: Any]],
              let firstItem = importedItems.first,
              let identityRef = firstItem[kSecImportItemIdentity as String]
        else {
            if status == errSecAuthFailed {
                throw CertificateFailure.incorrectPassword
            }
            throw CertificateFailure.importFailed(status)
        }

        // swiftlint:disable:next force_cast
        let identity = identityRef as! SecIdentity

        guard let info = getCertificateInfo(identity: identity) else {
            throw CertificateFailure.importFailed(errSecDecode)
        }

        if existingSerials.contains(info.serialNumber) {
            throw CertificateFailure.alreadyExists
        }

        // The side-effect insert is the normal case; add only if it did not
        // happen. A duplicate here means the item is present, which is the
        // outcome wanted either way.
        if findIdentity(serialNumber: info.serialNumber) == nil {
            var addQuery: [String: Any] = [kSecValueRef as String: identity]
            addAccessGroup(to: &addQuery)
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem
            else {
                throw CertificateFailure.storeFailed(addStatus)
            }
        }

        applyProtection(to: identity, alias: alias)

        // An import that reports success and stores nothing is a real failure,
        // not an empty result for the caller to discover later.
        guard findIdentity(serialNumber: info.serialNumber) != nil else {
            throw CertificateFailure.storeFailed(errSecItemNotFound)
        }
        return info
    }

    /// Applies the protection class to the private key and the label to the
    /// certificate, on the items the Keychain actually holds.
    ///
    /// Both are best-effort and deliberately do not throw: the certificate is
    /// imported and usable either way, and failing the whole import because a
    /// label did not stick would be worse than the label not sticking.
    ///
    /// The protection class is set here rather than on an add because
    /// `SecPKCS12Import` inserts the key with its own default, and an add that
    /// hits an existing item leaves that default in place. Private signing keys
    /// must not leave the device: `…ThisDeviceOnly` is excluded from backups,
    /// where the default class is restorable onto another device.
    /// `AfterFirstUnlock` rather than `WhenUnlocked` keeps signing working from
    /// a background launch after a reboot.
    private func applyProtection(to identity: SecIdentity, alias: String?) {
        var privateKey: SecKey?
        if SecIdentityCopyPrivateKey(identity, &privateKey) == errSecSuccess,
           let key = privateKey {
            var keyQuery: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecValueRef as String: key,
            ]
            addAccessGroup(to: &keyQuery)
            SecItemUpdate(
                keyQuery as CFDictionary,
                [
                    kSecAttrAccessible as String:
                        kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                ] as CFDictionary
            )
        }

        guard let alias, !alias.isEmpty else { return }
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
              let cert = certificate
        else {
            return
        }
        var certQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: cert,
        ]
        addAccessGroup(to: &certQuery)
        SecItemUpdate(
            certQuery as CFDictionary,
            [kSecAttrLabel as String: alias] as CFDictionary
        )
    }

    /// Finds an identity by its canonical serial number.
    ///
    /// The serial is the Keychain lookup key used across this plugin, and is
    /// the only identifier guaranteed to survive an import — a label may not
    /// attach to an identity add.
    func findIdentity(serialNumber: String) -> SecIdentity? {
        let wanted = Self.canonicalSerial(serialNumber)
        for (identity, _) in getAllIdentities()
        where getCertificateInfo(identity: identity)?.serialNumber == wanted {
            return identity
        }
        return nil
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

    /// Extracts the natively-sourced certificate info from a `SecIdentity`.
    ///
    /// Two things come from iOS: the serial number (the Keychain's own lookup
    /// key) and the DER bytes. Everything else is Dart's job — see the type
    /// doc.
    func getCertificateInfo(identity: SecIdentity) -> CertificateInfo? {
        var certificate: SecCertificate?
        let status = SecIdentityCopyCertificate(identity, &certificate)
        guard status == errSecSuccess, let cert = certificate else {
            return nil
        }

        return CertificateInfo(
            serialNumber: copySerialHex(from: cert),
            encoded: SecCertificateCopyData(cert) as Data,
            chain: copyCertificateChain(for: cert)
        )
    }

    /// Builds the certificate chain, leaf first.
    ///
    /// The signing service needs the intermediates to validate a certificate
    /// whose issuer it does not already hold, and unlike Android's
    /// `KeyChain.getCertificateChain` there is no API here that simply hands
    /// one over: the chain has to be built by evaluating trust, which is what
    /// makes iOS fill in the intermediates it holds.
    ///
    /// Evaluation is run for its side effect, and its **verdict is ignored**.
    /// An expired or untrusted certificate still yields the path that was
    /// built, and refusing to return one here would turn a signing attempt
    /// into a silent failure far from the cause. Whether to trust the
    /// certificate is `validateTrust(for:)`'s question, not this one.
    ///
    /// Returns an empty array if no path could be built at all; the Dart side
    /// then falls back to the leaf.
    private func copyCertificateChain(for certificate: SecCertificate) -> [Data] {
        guard let trust = createTrust(for: certificate) else { return [] }

        var error: CFError?
        _ = SecTrustEvaluateWithError(trust, &error)

        // SecTrustCopyCertificateChain arrived in iOS 15; this pod targets
        // 13. The older pair is deprecated rather than removed, and is the
        // only way to read the path on 13 and 14.
        let certificates: [SecCertificate]
        if #available(iOS 15.0, *) {
            certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate] ?? []
        } else {
            certificates = (0..<SecTrustGetCertificateCount(trust)).compactMap {
                SecTrustGetCertificateAtIndex(trust, $0)
            }
        }
        return certificates.map { SecCertificateCopyData($0) as Data }
    }

    // MARK: - Delete

    /// Deletes an identity from the Keychain by serial number.
    ///
    /// Deletes **only** the matching identity and its certificate. Other
    /// certificates in the access group are left untouched.
    func deleteIdentity(serialNumber: String) throws {
        // Canonicalise the incoming serial: it may have been persisted by an
        // earlier version in a platform-specific spelling.
        let wanted = Self.canonicalSerial(serialNumber)
        let identities = getAllIdentities()
        for (identity, _) in identities {
            if let info = getCertificateInfo(identity: identity),
               info.serialNumber == wanted {

                // Resolve the certificate *before* removing the identity, so
                // the follow-up delete is scoped to this exact item.
                var certificate: SecCertificate?
                SecIdentityCopyCertificate(identity, &certificate)

                var deleteQuery: [String: Any] = [
                    kSecClass as String: kSecClassIdentity,
                    kSecValueRef as String: identity,
                ]
                addAccessGroup(to: &deleteQuery)

                let status = SecItemDelete(deleteQuery as CFDictionary)
                guard status == errSecSuccess else {
                    throw CertificateFailure.deleteFailed(status)
                }

                // Remove the certificate if deleting the identity left it
                // behind. Scoped by `kSecValueRef` to this certificate alone.
                //
                // This previously queried `{ kSecClass: kSecClassCertificate }`
                // with no predicate, which matches every certificate in the
                // access group — deleting one certificate wiped them all.
                //
                // VERIFY: on-device, whether deleting the identity already
                // removes the certificate and private key. If it does, this
                // block is redundant and `errSecItemNotFound` is the expected
                // (and harmless) status here.
                if let cert = certificate {
                    var certDeleteQuery: [String: Any] = [
                        kSecClass as String: kSecClassCertificate,
                        kSecValueRef as String: cert,
                    ]
                    addAccessGroup(to: &certDeleteQuery)
                    SecItemDelete(certDeleteQuery as CFDictionary)
                }

                return
            }
        }
        throw CertificateFailure.notFound
    }

    // MARK: - Sign

    /// Signs data using the private key of the given identity.
    ///
    /// Takes a resolved `SecKeyAlgorithm` rather than a name: the mapping
    /// from the wire enum lives in the plugin, where it is exhaustive over
    /// `CertSignAlgorithmMessage`. This type previously mapped from a string
    /// and silently defaulted to SHA-256/RSA for anything unrecognised, which
    /// meant a bad value signed with RSA parameters against an EC key.
    func sign(
        data: Data,
        algorithm: SecKeyAlgorithm,
        identity: SecIdentity
    ) throws -> Data {
        var privateKey: SecKey?
        let status = SecIdentityCopyPrivateKey(identity, &privateKey)
        guard status == errSecSuccess, let key = privateKey else {
            throw CertificateFailure.signingFailed(
                reason: "Private key unavailable (OSStatus \(status))"
            )
        }

        var signError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            key,
            algorithm,
            data as CFData,
            &signError
        ) else {
            let reason = signError?.takeRetainedValue().localizedDescription
                ?? "Signing failed"
            throw CertificateFailure.signingFailed(reason: reason)
        }

        return signature as Data
    }

    // MARK: - Trust Validation

    /// Validates the trust chain for a certificate.
    func validateTrust(for identity: SecIdentity) -> Bool {
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(
            identity,
            &certificate
        ) == errSecSuccess,
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

    /// Copies the certificate serial number in canonical form.
    ///
    /// `SecCertificateCopySerialNumberData` (iOS 11+) returns the DER INTEGER
    /// content octets, which keep the sign-padding byte for values whose top
    /// bit is set (`0xB5A1C3` arrives as `00 b5 a1 c3`). Canonicalising strips
    /// that pad so the result matches Android and Dart for the same
    /// certificate.
    ///
    /// - SeeAlso: `CertificateSerial.canonical` (Dart) — the definition this
    ///   must agree with.
    private func copySerialHex(from cert: SecCertificate) -> String {
        var serialError: Unmanaged<CFError>?
        guard let serialData = SecCertificateCopySerialNumberData(
            cert,
            &serialError
        ) as Data? else {
            return ""
        }
        let hex = serialData.map { String(format: "%02x", $0) }.joined()
        return Self.canonicalSerial(hex)
    }

    /// Normalises a serial to lowercase hex with no sign pad and no leading
    /// zeros. `"0"` for an all-zero serial, `""` for empty input.
    ///
    /// Must stay behaviourally identical to `CertificateSerial.canonical`.
    static func canonicalSerial(_ serial: String) -> String {
        if serial.isEmpty { return "" }

        var hex = serial.lowercased().filter {
            $0 != " " && $0 != "\t" && $0 != ":" && $0 != "_" && $0 != "-"
        }
        if hex.hasPrefix("0x") { hex.removeFirst(2) }
        if hex.isEmpty { return "" }

        let stripped = hex.drop(while: { $0 == "0" })
        return stripped.isEmpty ? "0" : String(stripped)
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

/// The certificate facts that only iOS can supply.
///
/// Anything derivable from `encoded` is intentionally absent: it is decoded
/// once in Dart by `felectronic_x509` so both platforms agree by construction.
struct CertificateInfo {
    /// Lowercase hex of the DER INTEGER content octets, per
    /// `SecCertificateCopySerialNumberData`.
    ///
    /// - Warning: This is the Keychain lookup key. Dart must round-trip it
    ///   verbatim — do not normalize, re-case, or strip the DER sign pad, or
    ///   `deleteIdentity(serialNumber:)` will stop matching. Note this
    ///   encoding differs from Android's `BigInteger.toString(16)`, which
    ///   drops the leading zero pad.
    let serialNumber: String

    /// DER-encoded certificate: the single source of truth for issuer,
    /// validity and key usage.
    let encoded: Data

    /// The chain, leaf first, DER-encoded.
    ///
    /// Empty when a chain could not be built. That is not a claim the
    /// certificate is self-signed — only that the Keychain and the system
    /// anchors could not complete a path from it.
    let chain: [Data]
}
