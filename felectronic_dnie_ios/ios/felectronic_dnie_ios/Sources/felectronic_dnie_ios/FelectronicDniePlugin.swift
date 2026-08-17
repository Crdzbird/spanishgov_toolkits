import CoreNFC
import Flutter
// Security was previously visible only transitively, through the bridging
// header's include of DNIeManagerImports.h. That bridging header is gone
// (unsupported in framework targets), so the dependency is now explicit.
import Security
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

/// Public because `SignManager` exposes it in five `public` method
/// signatures; an internal protocol there is a compile error.
public protocol ElectronicDnieDelegate: AnyObject {
    func dnieReadingResult(result: DniResult)
    func dnieCertificateResult(certificate: String)
    func dnieError(error: NFCError)
    func dnieProbeResult(isValidDnie: Bool, atrHex: String, tagId: String)
}

extension FelectronicDniePlugin: ElectronicDnieDelegate {

    public func dnieReadingResult(result: DniResult) {
        let message = DnieSignedDataMessage(
            signedData: FlutterStandardTypedData(bytes: result.dataSigned),
            signedDataBase64: result.dataSignedString,
            certificate: result.certificate
        )
        replySign(.success(message))
    }

    public func dnieCertificateResult(certificate: String) {
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

    public func dnieProbeResult(isValidDnie: Bool, atrHex: String, tagId: String) {
        let message = DnieCardProbeMessage(
            isValidDnie: isValidDnie,
            atrHex: atrHex,
            tagId: tagId
        )
        replyProbe(.success(message))
    }

    public func dnieError(error: NFCError) {
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

        // This previously called `SecCertificateCopyValues`, which is declared
        // `__IPHONE_NA` — macOS only. The file therefore could not compile for
        // iOS at all; it went unnoticed because this package's CI workflow has
        // never run (it triggered on `main` while the branch is `master`).
        //
        // Only what iOS can actually answer is filled in here. Issuer, validity
        // and the exact subject serial are decoded from the certificate in Dart
        // by `felectronic_x509` — see `SignedDataX.parsedCertificate`, which
        // already parses this same base64 DER. That mirrors what the
        // felectronic_certificates suite does, and keeps Android and iOS from
        // disagreeing about the same certificate.
        let subjectCN = summary

        // SecCertificateCopySerialNumberData is iOS 11+.
        var serialHex = ""
        var serialError: Unmanaged<CFError>?
        if let serialData = SecCertificateCopySerialNumberData(
            secCert,
            &serialError
        ) as Data? {
            serialHex = serialData.map { String(format: "%02x", $0) }.joined()
        }

        // The subject DN is the one structured field the summary exposes.
        let subjectSerial = parseDNField(summary, field: "SERIALNUMBER")
            .replacingOccurrences(of: "IDCES-", with: "")

        // Not derivable through the iOS Security framework — Dart supplies
        // these from the DER. Empty/zero here means "ask the certificate",
        // not "the certificate says zero".
        let issuerCN = ""
        let issuerOrg = ""
        let notBefore: Int64 = 0
        let notAfter: Int64 = 0
        let isValid = false

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

        // Extracted from the subject summary rather than
        // `SecCertificateCopyValues`, which is macOS-only (see the note in
        // `parseCertificateDetails`). Dart re-derives both from the DER via
        // `felectronic_x509` when an exact value is needed.
        let nif = parseDNField(summary, field: "SERIALNUMBER")
            .replacingOccurrences(of: "IDCES-", with: "")
        let country = parseDNField(summary, field: "C")

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
