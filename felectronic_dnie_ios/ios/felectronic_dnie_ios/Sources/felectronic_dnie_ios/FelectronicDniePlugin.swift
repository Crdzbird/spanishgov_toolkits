import CoreNFC
import Flutter
import UIKit

public class FelectronicDniePlugin: NSObject, FlutterPlugin, FelectronicDnieHostApi {

    private var signManager = SignManager()
    private var pendingSignCompletion: ((Result<DnieSignedDataMessage, Error>) -> Void)?
    private var pendingCertCompletion: ((Result<DnieSignedDataMessage, Error>) -> Void)?
    private var pendingProbeCompletion: ((Result<DnieCardProbeMessage, Error>) -> Void)?
    private var pendingCertDetailsCompletion: ((Result<DnieCertificateDetailsMessage, Error>) -> Void)?
    private var pendingPersonalDataCompletion: ((Result<DniePersonalDataMessage, Error>) -> Void)?
    private var pendingVerifyCompletion: ((Result<Void, Error>) -> Void)?

    public static func register(
        with registrar: FlutterPluginRegistrar
    ) {
        let instance = FelectronicDniePlugin()
        FelectronicDnieHostApiSetup.setUp(
            binaryMessenger: registrar.messenger(),
            api: instance
        )
    }

    // MARK: - Certificate Alias Resolution

    /// Maps the `certificateType` string from Dart to the jmulticard
    /// certificate alias constant.
    private static func resolveCertAlias(_ certificateType: String) -> String {
        if certificateType == "AUTH" {
            return EsGobJmulticardCardDnieDnie.CERT_ALIAS_AUTH
        }
        return EsGobJmulticardCardDnieDnie.CERT_ALIAS_SIGN
    }

    // MARK: - FelectronicDnieHostApi

    func sign(
        data: FlutterStandardTypedData,
        can: String,
        pin: String,
        timeout: Int64,
        certificateType: String,
        completion: @escaping (Result<DnieSignedDataMessage, Error>) -> Void
    ) {
        pendingSignCompletion = completion
        let alias = Self.resolveCertAlias(certificateType)

        signManager.signPKCS1WithDNI(
            delegate: self,
            can: can,
            pin: pin,
            certAlias: alias,
            document: data.data
        )
    }

    func stopSign(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        pendingSignCompletion = nil
        pendingCertCompletion = nil
        pendingProbeCompletion = nil
        pendingCertDetailsCompletion = nil
        pendingPersonalDataCompletion = nil
        pendingVerifyCompletion = nil
        completion(.success(()))
    }

    func readCertificate(
        can: String,
        pin: String,
        timeout: Int64,
        certificateType: String,
        completion: @escaping (Result<DnieSignedDataMessage, Error>) -> Void
    ) {
        pendingCertCompletion = completion
        let alias = Self.resolveCertAlias(certificateType)

        signManager.getDNIeCertificate(
            delegate: self,
            can: can,
            pin: pin,
            certAlias: alias
        )
    }

    func probeCard(
        timeout: Int64,
        completion: @escaping (Result<DnieCardProbeMessage, Error>) -> Void
    ) {
        pendingProbeCompletion = completion

        signManager.probeDNIeCard(delegate: self)
    }

    func readCertificateDetails(
        can: String,
        pin: String,
        timeout: Int64,
        certificateType: String,
        completion: @escaping (Result<DnieCertificateDetailsMessage, Error>) -> Void
    ) {
        pendingCertDetailsCompletion = completion
        let alias = Self.resolveCertAlias(certificateType)

        signManager.getDNIeCertificate(
            delegate: self,
            can: can,
            pin: pin,
            certAlias: alias
        )
    }

    func readPersonalData(
        can: String,
        pin: String,
        timeout: Int64,
        certificateType: String,
        completion: @escaping (Result<DniePersonalDataMessage, Error>) -> Void
    ) {
        pendingPersonalDataCompletion = completion
        let alias = Self.resolveCertAlias(certificateType)

        signManager.getDNIeCertificate(
            delegate: self,
            can: can,
            pin: pin,
            certAlias: alias
        )
    }

    func verifyPin(
        can: String,
        pin: String,
        timeout: Int64,
        certificateType: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        pendingVerifyCompletion = completion
        let alias = Self.resolveCertAlias(certificateType)

        signManager.verifyDNIePin(
            delegate: self,
            can: can,
            pin: pin,
            certAlias: alias
        )
    }

    func checkNfcAvailability(
        completion: @escaping (Result<DnieNfcStatusMessage, Error>) -> Void
    ) {
        let isAvailable = NFCTagReaderSession.readingAvailable
        let message = DnieNfcStatusMessage(
            isAvailable: isAvailable,
            isEnabled: isAvailable
        )
        completion(.success(message))
    }

    // MARK: - Reply Helpers

    private func replySign(_ result: Result<DnieSignedDataMessage, Error>) {
        DispatchQueue.main.async { [weak self] in
            self?.pendingSignCompletion?(result)
            self?.pendingSignCompletion = nil
        }
    }

    private func replyCert(_ result: Result<DnieSignedDataMessage, Error>) {
        DispatchQueue.main.async { [weak self] in
            self?.pendingCertCompletion?(result)
            self?.pendingCertCompletion = nil
        }
    }

    private func replyProbe(_ result: Result<DnieCardProbeMessage, Error>) {
        DispatchQueue.main.async { [weak self] in
            self?.pendingProbeCompletion?(result)
            self?.pendingProbeCompletion = nil
        }
    }

    private func replyCertDetails(_ result: Result<DnieCertificateDetailsMessage, Error>) {
        DispatchQueue.main.async { [weak self] in
            self?.pendingCertDetailsCompletion?(result)
            self?.pendingCertDetailsCompletion = nil
        }
    }

    private func replyPersonalData(_ result: Result<DniePersonalDataMessage, Error>) {
        DispatchQueue.main.async { [weak self] in
            self?.pendingPersonalDataCompletion?(result)
            self?.pendingPersonalDataCompletion = nil
        }
    }

    private func replyVerify(_ result: Result<Void, Error>) {
        DispatchQueue.main.async { [weak self] in
            self?.pendingVerifyCompletion?(result)
            self?.pendingVerifyCompletion = nil
        }
    }
}

// MARK: - ElectronicDnieDelegate

protocol ElectronicDnieDelegate: AnyObject {
    func dnieReadingResult(result: DniResult)
    func dnieCertificateResult(certificate: String)
    func dnieError(error: NFCError)
    func dnieProbeResult(isValidDnie: Bool, atrHex: String, tagId: String)
}

extension FelectronicDniePlugin: ElectronicDnieDelegate {

    func dnieReadingResult(result: DniResult) {
        let message = DnieSignedDataMessage(
            signedData: FlutterStandardTypedData(bytes: result.dataSigned),
            signedDataBase64: result.dataSignedString,
            certificate: result.certificate
        )
        replySign(.success(message))
    }

    func dnieCertificateResult(certificate: String) {
        // Route to the appropriate pending completion
        if pendingCertDetailsCompletion != nil {
            let details = Self.parseCertificateDetails(fromBase64: certificate)
            replyCertDetails(.success(details))
        } else if pendingPersonalDataCompletion != nil {
            let personalData = Self.parsePersonalData(fromBase64: certificate)
            replyPersonalData(.success(personalData))
        } else if pendingVerifyCompletion != nil {
            replyVerify(.success(()))
        } else {
            let message = DnieSignedDataMessage(
                signedData: FlutterStandardTypedData(bytes: Data()),
                signedDataBase64: "",
                certificate: certificate
            )
            replyCert(.success(message))
        }
    }

    func dnieProbeResult(isValidDnie: Bool, atrHex: String, tagId: String) {
        let message = DnieCardProbeMessage(
            isValidDnie: isValidDnie,
            atrHex: atrHex,
            tagId: tagId
        )
        replyProbe(.success(message))
    }

    func dnieError(error: NFCError) {
        let flutterError = PigeonError(
            code: error.flutterErrorCode,
            message: error.flutterErrorMessage,
            details: nil
        )

        if pendingSignCompletion != nil {
            replySign(.failure(flutterError))
        } else if pendingCertCompletion != nil {
            replyCert(.failure(flutterError))
        } else if pendingProbeCompletion != nil {
            replyProbe(.failure(flutterError))
        } else if pendingCertDetailsCompletion != nil {
            replyCertDetails(.failure(flutterError))
        } else if pendingPersonalDataCompletion != nil {
            replyPersonalData(.failure(flutterError))
        } else if pendingVerifyCompletion != nil {
            replyVerify(.failure(flutterError))
        }
    }

    // MARK: - Certificate Parsing

    /// Parses X.509 certificate details from base64 DER.
    private static func parseCertificateDetails(fromBase64 certBase64: String) -> DnieCertificateDetailsMessage {
        guard let certData = Data(base64Encoded: certBase64),
              let secCert = SecCertificateCreateWithData(nil, certData as CFData) else {
            return DnieCertificateDetailsMessage(
                subjectCommonName: "",
                subjectSerialNumber: "",
                issuerCommonName: "",
                issuerOrganization: "",
                notValidBefore: 0,
                notValidAfter: 0,
                serialNumber: "",
                isCurrentlyValid: false
            )
        }

        let summary = SecCertificateCopySubjectSummary(secCert) as? String ?? ""

        // Extract fields from the certificate using Security framework
        var subjectCN = summary
        var subjectSerial = ""
        var issuerCN = ""
        var issuerOrg = ""
        var notBefore: Int64 = 0
        var notAfter: Int64 = 0
        var serialHex = ""
        var isValid = false

        if let values = SecCertificateCopyValues(secCert, nil, nil) as? [String: Any] {
            // Subject Name
            if let subjectName = values["2.5.4.3"] as? [String: Any],
               let value = subjectName["value"] as? String {
                subjectCN = value
            }
            // Subject Serial Number (NIF)
            if let serial = values["2.5.4.5"] as? [String: Any],
               let value = serial["value"] as? String {
                subjectSerial = value.replacingOccurrences(of: "IDCES-", with: "")
            }
            // Not Valid Before
            if let nvb = values["2.16.840.1.113741.2.1.1.1.3"] as? [String: Any],
               let value = nvb["value"] as? Date {
                notBefore = Int64(value.timeIntervalSince1970 * 1000)
            }
            // Not Valid After
            if let nva = values["2.16.840.1.113741.2.1.1.1.4"] as? [String: Any],
               let value = nva["value"] as? Date {
                notAfter = Int64(value.timeIntervalSince1970 * 1000)
            }
        }

        // Fallback: parse DN from summary for subject fields
        if subjectSerial.isEmpty {
            subjectSerial = parseDNField(summary, field: "SERIALNUMBER")
                .replacingOccurrences(of: "IDCES-", with: "")
        }

        // Try to get validity from the raw DER
        let now = Date()
        if notBefore > 0 && notAfter > 0 {
            let before = Date(timeIntervalSince1970: TimeInterval(notBefore) / 1000)
            let after = Date(timeIntervalSince1970: TimeInterval(notAfter) / 1000)
            isValid = now >= before && now <= after
        }

        return DnieCertificateDetailsMessage(
            subjectCommonName: subjectCN,
            subjectSerialNumber: subjectSerial,
            issuerCommonName: issuerCN,
            issuerOrganization: issuerOrg,
            notValidBefore: notBefore,
            notValidAfter: notAfter,
            serialNumber: serialHex,
            isCurrentlyValid: isValid
        )
    }

    /// Parses personal data from the X.509 certificate subject DN.
    private static func parsePersonalData(fromBase64 certBase64: String) -> DniePersonalDataMessage {
        guard let certData = Data(base64Encoded: certBase64),
              let secCert = SecCertificateCreateWithData(nil, certData as CFData) else {
            return DniePersonalDataMessage(
                fullName: "",
                givenName: "",
                surnames: "",
                nif: "",
                country: "",
                certificateType: ""
            )
        }

        let summary = SecCertificateCopySubjectSummary(secCert) as? String ?? ""
        let cn = summary

        // Parse CN: "APELLIDO1 APELLIDO2, NOMBRE (FIRMA)"
        var surnames = ""
        var givenName = ""
        var certificateType = ""

        // Extract certificate type from parentheses
        if let parenStart = cn.range(of: "("),
           let parenEnd = cn.range(of: ")", range: parenStart.upperBound..<cn.endIndex) {
            certificateType = String(cn[parenStart.upperBound..<parenEnd.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        // Extract name parts before parenthesis
        let nameWithoutType: String
        if let parenStart = cn.range(of: "(") {
            nameWithoutType = String(cn[cn.startIndex..<parenStart.lowerBound]).trimmingCharacters(in: .whitespaces)
        } else {
            nameWithoutType = cn
        }

        if let commaRange = nameWithoutType.range(of: ",") {
            surnames = String(nameWithoutType[nameWithoutType.startIndex..<commaRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            givenName = String(nameWithoutType[commaRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else {
            surnames = nameWithoutType
        }

        let fullName = givenName.isEmpty ? surnames : "\(givenName) \(surnames)"

        // Extract NIF from SERIALNUMBER
        var nif = ""
        if let values = SecCertificateCopyValues(secCert, nil, nil) as? [String: Any],
           let serial = values["2.5.4.5"] as? [String: Any],
           let value = serial["value"] as? String {
            nif = value.replacingOccurrences(of: "IDCES-", with: "")
        }

        // Extract country
        var country = ""
        if let values = SecCertificateCopyValues(secCert, nil, nil) as? [String: Any],
           let c = values["2.5.4.6"] as? [String: Any],
           let value = c["value"] as? String {
            country = value
        }

        return DniePersonalDataMessage(
            fullName: fullName,
            givenName: givenName,
            surnames: surnames,
            nif: nif,
            country: country,
            certificateType: certificateType
        )
    }

    private static func parseDNField(_ dn: String, field: String) -> String {
        let pattern = "\(field)=([^,]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: dn, range: NSRange(dn.startIndex..., in: dn)),
              let range = Range(match.range(at: 1), in: dn) else {
            return ""
        }
        return String(dn[range]).trimmingCharacters(in: .whitespaces)
    }
}
